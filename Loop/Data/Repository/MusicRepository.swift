//
//  MusicRepository.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import SwiftData
import OSLog
import UIKit

@MainActor
final class MusicRepository {
    
    // MARK: - Dependencies
    private let db: MusicDatabase
    private let client: NavidromeClient
    private let logger = Logger(subsystem: "com.loopapp", category: "Repo")
    private let fileManager = FileManager.default
    
    private var context: ModelContext {
        db.container.mainContext
    }
    
    // Path for storing covers
    private var coversDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Covers")
    }
    
    init(db: MusicDatabase, client: NavidromeClient) {
        self.db = db
        self.client = client
        try? fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Player Lookups (Required by AudioEngine)
    
    func song(id: String) async -> Loop.Song? {
        let predicate = #Predicate<Loop.Song> { $0.id == id }
        var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    func getCoverArtId(for songId: String) async -> String? {
        if let s = await song(id: songId) {
            return s.album?.coverArtId
        }
        return nil
    }
    
    // MARK: - Local Reads (Offline-First)
    
    func getLocalAlbum(id: String) -> Loop.Album? {
        let descriptor = FetchDescriptor<Loop.Album>(predicate: #Predicate<Loop.Album> { $0.id == id })
        return try? context.fetch(descriptor).first
    }
    
    func getLocalSongs(for albumId: String) -> [Loop.Song] {
        let descriptor = FetchDescriptor<Loop.Song>(
            predicate: #Predicate<Loop.Song> { $0.albumId == albumId },
            sortBy: [SortDescriptor(\.trackNumber)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getLocalArtist(id: String) -> Loop.Artist? {
        let descriptor = FetchDescriptor<Loop.Artist>(predicate: #Predicate<Loop.Artist> { $0.id == id })
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Artist Details (Required by ArtistDetailViewModel)
    
    func getArtistWithAlbums(id: String) async throws -> (artist: Loop.Artist?, albums: [Loop.Album]) {
        // 1. Try Local
        let localArtist = getLocalArtist(id: id)
        
        // 2. Refresh from Server (Background)
        if let remote = try? await client.fetchArtist(id: id) {
            let artist: Loop.Artist
            if let existing = localArtist {
                artist = existing
                artist.name = remote.name
            } else {
                artist = Loop.Artist(id: remote.id, name: remote.name)
                context.insert(artist)
            }
            
            if let remoteAlbums = remote.album {
                for ra in remoteAlbums {
                    let albumId = ra.id
                    let albumDesc = FetchDescriptor<Loop.Album>(predicate: #Predicate<Loop.Album> { $0.id == albumId })
                    
                    if let existing = try? context.fetch(albumDesc).first {
                        existing.coverArtId = ra.coverArt
                    } else {
                        let newAlbum = Loop.Album(
                            id: ra.id,
                            title: ra.name,
                            artistId: ra.artistId,
                            coverArtId: ra.coverArt,
                            year: ra.year
                        )
                        newAlbum.artist = artist
                        context.insert(newAlbum)
                    }
                }
            }
            try? context.save()
        }
        
        // 3. Return Data
        let albumPredicate = #Predicate<Loop.Album> { $0.artistId == id }
        let albumsDesc = FetchDescriptor<Loop.Album>(predicate: albumPredicate, sortBy: [SortDescriptor(\.year, order: .reverse)])
        let albums = (try? context.fetch(albumsDesc)) ?? []
        
        return (localArtist, albums)
    }
    
    // MARK: - Sync Logic (Offline-First)
    
    func syncAlbumDetails(albumId: String) async {
        guard let response: SubsonicGetAlbumResponse = try? await client.fetch("getAlbum", params: ["id": albumId]),
              let details = response.subsonicResponse.album,
              let remoteSongs = details.song else { return }
        
        // Ensure Album
        let album: Loop.Album
        if let existing = getLocalAlbum(id: albumId) {
            album = existing
        } else {
            let artistId = details.artistId
            let artist = getLocalArtist(id: artistId) ?? Loop.Artist(id: details.artistId, name: details.artist)
            if artist.modelContext == nil { context.insert(artist) }
            
            album = Loop.Album(id: details.id, title: details.name, artistId: details.artistId, coverArtId: details.coverArt, year: details.year)
            album.artist = artist
            context.insert(album)
        }
        
        // Sync Songs
        for remote in remoteSongs {
            let remoteId = remote.id
            let songDesc = FetchDescriptor<Loop.Song>(predicate: #Predicate<Loop.Song> { $0.id == remoteId })
            
            if (try? context.fetch(songDesc).first) == nil {
                let song = Loop.Song(
                    id: remote.id,
                    title: remote.title,
                    trackNumber: remote.track ?? 0,
                    duration: TimeInterval(remote.duration ?? 0),
                    path: remote.path ?? "",
                    artistId: album.artistId,
                    albumId: album.id
                )
                song.album = album
                song.artist = album.artist
                context.insert(song)
            }
        }
        try? context.save()
    }
    
    func syncSmart(onProgress: @escaping (Bool) -> Void) async {
        onProgress(true)
        
        // 1. Metadata Sync (Newest 50)
        if let response: SubsonicResponse = try? await client.fetch("getAlbumList2", params: ["type": "newest", "size": "50"]),
           let albums = response.subsonicResponse.albumList2?.album {
            await saveBatch(albums)
        }
        
        // 2. Metadata Sync (Alphabetical 2000 - Example)
        if let response: SubsonicResponse = try? await client.fetch("getAlbumList2", params: ["type": "alphabeticalByName", "size": "2000"]),
           let albums = response.subsonicResponse.albumList2?.album {
            await saveBatch(albums)
        }
        
        try? await syncGenres()
        
        // 3. ✅ NEW: Prefetch Cover Art for Offline Use
        logger.info("🎨 Starting Cover Art Prefetch...")
        await prefetchCovers()
        
        onProgress(false)
    }
    
    private func saveBatch(_ remoteAlbums: [RemoteAlbum]) async {
        for remote in remoteAlbums {
            let albumId = remote.id
            let descriptor = FetchDescriptor<Loop.Album>(predicate: #Predicate<Loop.Album> { $0.id == albumId })
            
            if let existing = try? context.fetch(descriptor).first {
                existing.coverArtId = remote.coverArt
            } else {
                let artistId = remote.artistId
                let artist = getLocalArtist(id: artistId) ?? Loop.Artist(id: remote.artistId, name: remote.artist)
                if artist.modelContext == nil { context.insert(artist) }
                
                let newAlbum = Loop.Album(
                    id: remote.id,
                    title: remote.name,
                    artistId: remote.artistId,
                    coverArtId: remote.coverArt,
                    year: remote.year,
                    genre: remote.genre
                )
                newAlbum.artist = artist
                context.insert(newAlbum)
            }
        }
        try? context.save()
    }
    
    private func prefetchCovers() async {
        // Fetch all albums that have a coverArtId
        let descriptor = FetchDescriptor<Loop.Album>()
        guard let albums = try? context.fetch(descriptor) else { return }
        
        // Use a TaskGroup to download in parallel (capped concurrency logic would be better for massive libs)
        await withTaskGroup(of: Void.self) { group in
            for album in albums {
                guard let coverId = album.coverArtId else { continue }
                
                // Check if file already exists
                let url = coversDirectory.appendingPathComponent("\(coverId).jpg")
                if fileManager.fileExists(atPath: url.path) { continue }
                
                // Start download task (Small size 300 for grid view)
                group.addTask {
                    if let remoteURL = self.client.coverArtURL(id: coverId, size: 300),
                       let data = try? await self.client.downloadData(from: remoteURL) {
                        try? data.write(to: url)
                    }
                }
            }
        }
        logger.info("✅ Cover Art Prefetch Complete")
    }
    
    func syncGenres() async throws {
        let remoteGenres = try await client.getGenres()
        for rg in remoteGenres {
            let name = rg.value
            if name.isEmpty { continue }
            let predicate = #Predicate<Loop.Genre> { $0.name == name }
            var descriptor = FetchDescriptor<Loop.Genre>(predicate: predicate)
            descriptor.fetchLimit = 1
            
            if let existing = try? context.fetch(descriptor).first {
                existing.albumCount = rg.albumCount
                existing.songCount = rg.songCount
            } else {
                context.insert(Loop.Genre(name: rg.value, albumCount: rg.albumCount, songCount: rg.songCount))
            }
        }
        try? context.save()
    }
    
    // MARK: - Basic Fetchers
    
    func getAlbums(forGenre genre: String) async throws -> [Loop.Album] {
        let predicate = #Predicate<Loop.Album> {
            $0.genre?.localizedStandardContains(genre) ?? false
        }
        let descriptor = FetchDescriptor<Loop.Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func getAlbums(limit: Int = 5000) async throws -> [Loop.Album] {
        var descriptor = FetchDescriptor<Loop.Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func getArtists() async throws -> [Loop.Artist] {
        return try context.fetch(FetchDescriptor<Loop.Artist>(sortBy: [SortDescriptor(\.name)]))
    }
    
    func getGenres() async throws -> [Loop.Genre] {
        return try context.fetch(FetchDescriptor<Loop.Genre>(sortBy: [SortDescriptor(\.name)]))
    }
    
    func ensureSongExists(id: String) async {
         guard (try? await client.fetchSong(id: id)) != nil else { return }
    }
}

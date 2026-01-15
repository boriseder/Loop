//
//  MusicRepository.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import SwiftData
import OSLog

@MainActor
final class MusicRepository {
    
    // MARK: - Dependencies
    private let db: MusicDatabase
    private let client: NavidromeClient
    private let logger = Logger(subsystem: "com.loopapp", category: "Repo")
    
    private var context: ModelContext {
        db.container.mainContext
    }
    
    init(db: MusicDatabase, client: NavidromeClient) {
        self.db = db
        self.client = client
    }
    
    // MARK: - Data Access (Read)
    
    func getAlbums(limit: Int = 20, offset: Int = 0) async throws -> [Loop.Album] {
        var descriptor = FetchDescriptor<Loop.Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try context.fetch(descriptor)
    }
    
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
    
    func getSongs(for albumId: String) async throws -> [Loop.Song] {
        let predicate = #Predicate<Loop.Song> { $0.albumId == albumId }
        let descriptor = FetchDescriptor<Loop.Song>(predicate: predicate, sortBy: [SortDescriptor(\.trackNumber)])
        return try context.fetch(descriptor)
    }
    
    func song(id: String) async -> Loop.Song? {
        let predicate = #Predicate<Loop.Song> { $0.id == id }
        var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    func getArtists() async throws -> [Loop.Artist] {
        let descriptor = FetchDescriptor<Loop.Artist>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }
    
    func getGenres() async throws -> [Loop.Genre] {
        let descriptor = FetchDescriptor<Loop.Genre>(sortBy: [SortDescriptor(\.name)])
        let result = try context.fetch(descriptor)
        logger.info("📖 Repository read: \(result.count) genres from DB")
        return result
    }
    
    func getCoverArtId(for songId: String) async -> String? {
        let songPredicate = #Predicate<Loop.Song> { $0.id == songId }
        var songDescriptor = FetchDescriptor<Loop.Song>(predicate: songPredicate)
        songDescriptor.fetchLimit = 1
        
        guard let song = try? context.fetch(songDescriptor).first else { return nil }
        
        let albumId = song.albumId
        let albumPredicate = #Predicate<Loop.Album> { $0.id == albumId }
        var albumDescriptor = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
        albumDescriptor.fetchLimit = 1
        
        return try? context.fetch(albumDescriptor).first?.coverArtId
    }
    
    // MARK: - Artist Logic
    
    func getArtistWithAlbums(id: String) async throws -> (artist: Loop.Artist?, albums: [Loop.Album]) {
        let artistPredicate = #Predicate<Loop.Artist> { $0.id == id }
        var artistDesc = FetchDescriptor<Loop.Artist>(predicate: artistPredicate)
        artistDesc.fetchLimit = 1
        let localArtist = try? context.fetch(artistDesc).first
        
        if let remote = try? await client.fetchArtist(id: id) {
            let artist: Loop.Artist
            if let local = localArtist {
                artist = local
            } else {
                artist = Loop.Artist(id: remote.id, name: remote.name)
                context.insert(artist)
            }
            
            if let remoteAlbums = remote.album {
                for ra in remoteAlbums {
                    let albumId = ra.id
                    let albumPredicate = #Predicate<Loop.Album> { $0.id == albumId }
                    var albumDesc = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
                    albumDesc.fetchLimit = 1
                    
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
        
        let albumPredicate = #Predicate<Loop.Album> { $0.artistId == id }
        let albumsDesc = FetchDescriptor<Loop.Album>(predicate: albumPredicate, sortBy: [SortDescriptor(\.year, order: .reverse)])
        let albums = (try? context.fetch(albumsDesc)) ?? []
        
        return (localArtist, albums)
    }
    
    // MARK: - Sync Logic (Write)
    
    func syncAlbums() async throws {
        let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: ["type": "newest", "size": "50"])
        guard let remoteAlbums = response.subsonicResponse.albumList2?.album else { return }
        
        var artistCache: [String: Loop.Artist] = [:]
        
        for remote in remoteAlbums {
            let artist: Loop.Artist
            if let cached = artistCache[remote.artistId] {
                artist = cached
            } else {
                let artistId = remote.artistId
                let predicate = #Predicate<Loop.Artist> { $0.id == artistId }
                var descriptor = FetchDescriptor<Loop.Artist>(predicate: predicate)
                descriptor.fetchLimit = 1
                
                if let existing = try? context.fetch(descriptor).first {
                    artist = existing
                } else {
                    let newArtist = Loop.Artist(id: remote.artistId, name: remote.artist)
                    context.insert(newArtist)
                    artist = newArtist
                }
                artistCache[remote.artistId] = artist
            }
            
            let albumId = remote.id
            let albumPredicate = #Predicate<Loop.Album> { $0.id == albumId }
            var albumDescriptor = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
            albumDescriptor.fetchLimit = 1
            
            if let existingAlbum = try? context.fetch(albumDescriptor).first {
                existingAlbum.coverArtId = remote.coverArt
                existingAlbum.genre = remote.genre
            } else {
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
        
        try? await syncGenres()
        try context.save()
        logger.info("✅ Synced albums and genres")
    }
    
    func syncGenres() async throws {
        let remoteGenres = try await client.getGenres()
        logger.info("🌍 Received \(remoteGenres.count) genres from API")
        
        var insertCount = 0
        var updateCount = 0
        
        for rg in remoteGenres {
            let name = rg.value
            if name.isEmpty { continue }
            
            let predicate = #Predicate<Loop.Genre> { $0.name == name }
            var descriptor = FetchDescriptor<Loop.Genre>(predicate: predicate)
            descriptor.fetchLimit = 1
            
            do {
                if let existing = try context.fetch(descriptor).first {
                    existing.albumCount = rg.albumCount
                    existing.songCount = rg.songCount
                    updateCount += 1
                } else {
                    let newGenre = Loop.Genre(
                        name: rg.value,
                        albumCount: rg.albumCount,
                        songCount: rg.songCount
                    )
                    context.insert(newGenre)
                    insertCount += 1
                }
            } catch {
                logger.error("❌ Error fetching/inserting genre '\(name)': \(error)")
            }
        }
        
        do {
            try context.save()
            logger.info("💾 DB Save Success: Inserted \(insertCount), Updated \(updateCount)")
        } catch {
            logger.error("❌ DB Save Failed: \(error)")
        }
    }
    
    func syncAlbumDetails(albumId: String) async throws {
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        guard let details = response.subsonicResponse.album,
              let remoteSongs = details.song else { return }
        
        let albumPredicate = #Predicate<Loop.Album> { $0.id == albumId }
        var albumDescriptor = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
        albumDescriptor.fetchLimit = 1
        
        let album: Loop.Album
        
        if let existingAlbum = try? context.fetch(albumDescriptor).first {
            album = existingAlbum
        } else {
            logger.info("🆕 Creating missing album: \(details.name)")
            
            let artistId = details.artistId
            let artistPredicate = #Predicate<Loop.Artist> { $0.id == artistId }
            var artistDescriptor = FetchDescriptor<Loop.Artist>(predicate: artistPredicate)
            artistDescriptor.fetchLimit = 1
            
            let artist: Loop.Artist
            if let existingArtist = try? context.fetch(artistDescriptor).first {
                artist = existingArtist
            } else {
                artist = Loop.Artist(id: details.artistId, name: details.artist)
                context.insert(artist)
            }
            
            album = Loop.Album(
                id: details.id,
                title: details.name,
                artistId: details.artistId,
                coverArtId: details.coverArt,
                year: details.year
            )
            album.artist = artist
            context.insert(album)
        }
        
        for remote in remoteSongs {
            let songId = remote.id
            let songPredicate = #Predicate<Loop.Song> { $0.id == songId }
            var songDesc = FetchDescriptor<Loop.Song>(predicate: songPredicate)
            songDesc.fetchLimit = 1
            
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
        
        try context.save()
    }
    
    func search(query: String) async throws -> (songs: [RemoteSong], albums: [RemoteAlbum], artists: [RemoteArtist]) {
        return try await client.search(query: query)
    }
    
    func ensureSongExists(id: String) async {
        // ✅ FIX: Replaced unused variable binding with boolean check
        guard (try? await client.fetchSong(id: id)) != nil else { return }
    }
}

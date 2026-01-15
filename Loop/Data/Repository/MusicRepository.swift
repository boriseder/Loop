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
    
    init(db: MusicDatabase, client: NavidromeClient) {
        self.db = db
        self.client = client
    }
    
    // MARK: - Album Data
    
    func getAlbums(limit: Int = 20, offset: Int = 0) async throws -> [Album] {
        let context = ModelContext(db.container)
        var descriptor = FetchDescriptor<Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try context.fetch(descriptor)
    }

    // MARK: - Artist Data
        
    func getArtists() async throws -> [Artist] {
        let context = ModelContext(db.container)
        // Sort artists alphabetically
        let descriptor = FetchDescriptor<Artist>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }
    
    // MARK: - Song Data

    func getSongs(for albumId: String) async throws -> [Song] {
        let context = ModelContext(db.container)
        let predicate = #Predicate<Song> { $0.albumId == albumId }
        let descriptor = FetchDescriptor<Song>(predicate: predicate, sortBy: [SortDescriptor(\.trackNumber)])
        return try context.fetch(descriptor)
    }
    
    func song(id: String) async -> Song? {
        let context = ModelContext(db.container)
        let predicate = #Predicate<Song> { $0.id == id }
        var descriptor = FetchDescriptor<Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    func getCoverArtId(for songId: String) async -> String? {
        let context = ModelContext(db.container)
        
        // 1. Fetch Song
        let songPredicate = #Predicate<Song> { $0.id == songId }
        var songDescriptor = FetchDescriptor<Song>(predicate: songPredicate)
        songDescriptor.fetchLimit = 1
        
        guard let song = try? context.fetch(songDescriptor).first else { return nil }
        
        // 2. Resolve Album (safe via ID)
        let albumId = song.albumId
        let albumPredicate = #Predicate<Album> { $0.id == albumId }
        var albumDescriptor = FetchDescriptor<Album>(predicate: albumPredicate)
        albumDescriptor.fetchLimit = 1
        
        if let album = try? context.fetch(albumDescriptor).first {
            return album.coverArtId
        }
        
        return nil
    }
    
    // MARK: - Just-In-Time Sync (New)
    
    func ensureSongExists(id: String) async {
        let context = ModelContext(db.container)
        
        // 1. Check if exists locally
        let predicate = #Predicate<Song> { $0.id == id }
        var descriptor = FetchDescriptor<Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if (try? context.fetch(descriptor).first) != nil {
            return // ✅ Already exists
        }
        
        // 2. Not found. Fetch from Network.
        logger.info("⚠️ Song \(id) missing locally. Fetching...")
        
        guard let remoteSong = try? await client.fetchSong(id: id),
              let albumId = remoteSong.albumId else {
            logger.error("❌ Failed to fetch song or missing albumId for \(id)")
            return
        }
        
        // 3. Sync the Parent Album
        // This implicitly inserts the Album, Artist, and the Song itself (and its siblings)
        try? await syncAlbumDetails(albumId: albumId)
    }
    
    // MARK: - Artist Logic
    
    func getArtistWithAlbums(id: String) async throws -> (artist: Artist?, albums: [Album]) {
        let context = ModelContext(db.container)
        
        // 1. Fetch Local Artist first
        let artistPredicate = #Predicate<Artist> { $0.id == id }
        var artistDesc = FetchDescriptor<Artist>(predicate: artistPredicate)
        artistDesc.fetchLimit = 1
        let localArtist = try? context.fetch(artistDesc).first
        
        // 2. Fetch Network Data
        if let remote = try? await client.fetchArtist(id: id) {
            
            // Upsert Artist
            let artist: Artist
            if let local = localArtist {
                artist = local
            } else {
                artist = Artist(id: remote.id, name: remote.name)
                context.insert(artist)
            }
            
            // Sync Albums
            if let remoteAlbums = remote.album {
                for ra in remoteAlbums {
                    let albumId = ra.id
                    let albumPredicate = #Predicate<Album> { $0.id == albumId }
                    var albumDesc = FetchDescriptor<Album>(predicate: albumPredicate)
                    albumDesc.fetchLimit = 1
                    
                    if let existing = try? context.fetch(albumDesc).first {
                        existing.coverArtId = ra.coverArt
                    } else {
                        let newAlbum = Album(
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
        
        // 3. Return Fresh Data
        let albumPredicate = #Predicate<Album> { $0.artistId == id }
        let albumsDesc = FetchDescriptor<Album>(
            predicate: albumPredicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        let albums = (try? context.fetch(albumsDesc)) ?? []
        
        return (localArtist, albums)
    }
    
    // MARK: - Sync Logic (Write)
    
    func syncAlbums() async throws {
        let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: ["type": "newest", "size": "50"])
        
        guard let remoteAlbums = response.subsonicResponse.albumList2?.album else { return }
        
        let context = ModelContext(db.container)
        var artistCache: [String: Artist] = [:]
        
        for remote in remoteAlbums {
            // Resolve Artist
            let artist: Artist
            if let cached = artistCache[remote.artistId] {
                artist = cached
            } else {
                let artistId = remote.artistId
                let predicate = #Predicate<Artist> { $0.id == artistId }
                var descriptor = FetchDescriptor<Artist>(predicate: predicate)
                descriptor.fetchLimit = 1
                
                if let existing = try? context.fetch(descriptor).first {
                    artist = existing
                } else {
                    let newArtist = Artist(id: remote.artistId, name: remote.artist)
                    context.insert(newArtist)
                    artist = newArtist
                }
                artistCache[remote.artistId] = artist
            }
            
            // Resolve Album
            let albumId = remote.id
            let albumPredicate = #Predicate<Album> { $0.id == albumId }
            var albumDescriptor = FetchDescriptor<Album>(predicate: albumPredicate)
            albumDescriptor.fetchLimit = 1
            
            if let existingAlbum = try? context.fetch(albumDescriptor).first {
                existingAlbum.coverArtId = remote.coverArt
            } else {
                let newAlbum = Album(
                    id: remote.id,
                    title: remote.name,
                    artistId: remote.artistId,
                    coverArtId: remote.coverArt,
                    year: remote.year
                )
                newAlbum.artist = artist
                context.insert(newAlbum)
            }
        }
        
        try context.save()
        logger.info("✅ Synced \(remoteAlbums.count) albums")
    }
    
    func syncAlbumDetails(albumId: String) async throws {
        // 1. Fetch details
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        
        guard let details = response.subsonicResponse.album,
              let remoteSongs = details.song else { return }
        
        let context = ModelContext(db.container)
        
        // 2. Resolve Parent Album (Create if missing!)
        let albumPredicate = #Predicate<Album> { $0.id == albumId }
        var albumDescriptor = FetchDescriptor<Album>(predicate: albumPredicate)
        albumDescriptor.fetchLimit = 1
        
        let album: Album
        
        if let existingAlbum = try? context.fetch(albumDescriptor).first {
            album = existingAlbum
        } else {
            logger.info("🆕 Parent album missing. Creating: \(details.name)")
            
            // 2a. Resolve Artist (Create if missing)
            let artistId = details.artistId
            let artistPredicate = #Predicate<Artist> { $0.id == artistId }
            var artistDescriptor = FetchDescriptor<Artist>(predicate: artistPredicate)
            artistDescriptor.fetchLimit = 1
            
            let artist: Artist
            if let existingArtist = try? context.fetch(artistDescriptor).first {
                artist = existingArtist
            } else {
                artist = Artist(id: details.artistId, name: details.artist)
                context.insert(artist)
            }
            
            // 2b. Create Album
            album = Album(
                id: details.id,
                title: details.name,
                artistId: details.artistId,
                coverArtId: details.coverArt,
                year: details.year
            )
            album.artist = artist
            context.insert(album)
        }
        
        // 3. Sync Songs
        for remote in remoteSongs {
            let songId = remote.id
            let songPredicate = #Predicate<Song> { $0.id == songId }
            var songDesc = FetchDescriptor<Song>(predicate: songPredicate)
            songDesc.fetchLimit = 1
            
            if (try? context.fetch(songDesc).first) == nil {
                let song = Song(
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
        logger.info("✅ Synced \(remoteSongs.count) songs for album: \(album.title)")
    }
    
    // MARK: - Search
    
    func search(query: String) async throws -> (songs: [RemoteSong], albums: [RemoteAlbum], artists: [RemoteArtist]) {
        return try await client.search(query: query)
    }
}

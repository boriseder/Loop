//  MusicRepository.swift

import Foundation
import SwiftData
import OSLog

actor MusicRepository {
    private let client: NavidromeClient
    private let container: ModelContainer
    private let logger = Logger(subsystem: "com.loopapp", category: "MusicRepository")
    
    init(db: MusicDatabase, client: NavidromeClient) {
        self.client = client
        self.container = db.container
    }
    
    // MARK: - Write
    func syncAlbums() async throws {
        // Fetch
        let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: ["type": "newest", "size": "50"])
        
        guard let remoteAlbums = response.subsonicResponse.albumList2?.album else { return }
        
        let context = ModelContext(container)
        
        // ✅ FIX: Deduplicate Artists in memory.
        // This prevents creating multiple instances for the same Artist ID in one batch.
        var artistCache: [String: Artist] = [:]
        
        for remote in remoteAlbums {
            let artist: Artist
            
            // 1. Check if we already created this Artist in this loop
            if let cachedArtist = artistCache[remote.artistId] {
                artist = cachedArtist
            } else {
                // 2. If not, create a new one and cache it
                // Note: We create it with the ID. SwiftData's @Attribute(.unique)
                // will handle merging this with the Database on save.
                let newArtist = Artist(id: remote.artistId, name: remote.artist)
                context.insert(newArtist)
                artistCache[remote.artistId] = newArtist
                artist = newArtist
            }
            
            // 3. Create Album and link relationship
            let album = Album(id: remote.id, title: remote.name, artistId: remote.artistId, coverArtId: remote.coverArt, year: remote.year)
            album.artist = artist
            
            context.insert(album)
        }
        
        try context.save()
        logger.info("✅ Synced \(remoteAlbums.count) albums")
    }
    
    func syncAlbumDetails(albumId: String) async throws {
        // 1. Fetch from Network
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        
        guard let songs = response.subsonicResponse.album?.song else { return }
        
        let context = ModelContext(container)
        
        // 2. Fetch the Parent Album to link relationships
        let albumPredicate = #Predicate<Album> { $0.id == albumId }
        var albumDescriptor = FetchDescriptor<Album>(predicate: albumPredicate)
        albumDescriptor.fetchLimit = 1
        
        guard let localAlbum = try context.fetch(albumDescriptor).first else {
            logger.warning("⚠️ Parent album \(albumId) not found locally.")
            return
        }
        
        // 3. Insert Songs
        for remote in songs {
            // Check if song exists to avoid duplicates
            let songId = remote.id
            let existingPredicate = #Predicate<Song> { $0.id == songId }
            var existingDesc = FetchDescriptor<Song>(predicate: existingPredicate)
            existingDesc.fetchLimit = 1
            
            if (try? context.fetch(existingDesc).first) != nil { continue }
            
            // Create Song
            let newSong = Song(
                id: remote.id,
                title: remote.title,
                trackNumber: remote.track ?? 0,
                duration: TimeInterval(remote.duration ?? 0),
                path: remote.path ?? "",
                artistId: localAlbum.artistId,
                albumId: albumId
            )
            
            // Link Relationships
            newSong.album = localAlbum
            newSong.artist = localAlbum.artist
            
            context.insert(newSong)
        }
        
        try context.save()
        logger.info("✅ Synced \(songs.count) songs for album \(localAlbum.title)")
    }
    
    
    // ✅ Separate method to isolate the fetch
    private func fetchAlbums() async throws -> SubsonicResponse {
        try await client.fetch("getAlbumList2", params: ["type": "newest", "size": "50"])
    }
    
    // MARK: - Read
    func getAlbums(limit: Int = 100, offset: Int = 0) async throws -> [Album] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try context.fetch(descriptor)
    }
    
    func getSongs(for albumId: String) async throws -> [Song] {
        let context = ModelContext(container)
        let predicate = #Predicate<Song> { $0.albumId == albumId }
        let descriptor = FetchDescriptor<Song>(predicate: predicate, sortBy: [SortDescriptor(\.trackNumber)])
        return try context.fetch(descriptor)
    }
    
    func song(id: String) async -> Song? {
        let context = ModelContext(container)
        let predicate = #Predicate<Song> { $0.id == id }
        var descriptor = FetchDescriptor<Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Safe Metadata Fetch
    
    /// Thread-safe helper to get cover art ID without passing Model objects
    func getCoverArtId(for songId: String) async -> String? {
        let context = ModelContext(container)
        
        // 1. Fetch the Song to get the albumId (Primitive property, safer than relationship)
        let songPredicate = #Predicate<Song> { $0.id == songId }
        var songDescriptor = FetchDescriptor<Song>(predicate: songPredicate)
        songDescriptor.fetchLimit = 1
        
        guard let song = try? context.fetch(songDescriptor).first else {
            print("❌ Repo: Song not found for ID \(songId)")
            return nil
        }
        
        // 2. Use the primitive 'albumId' to find the Album directly
        // This bypasses potential relationship faults on background threads
        let albumId = song.albumId
        let albumPredicate = #Predicate<Album> { $0.id == albumId }
        var albumDescriptor = FetchDescriptor<Album>(predicate: albumPredicate)
        albumDescriptor.fetchLimit = 1
        
        if let album = try? context.fetch(albumDescriptor).first {
            print("✅ Repo: Found Album \(album.title), CoverID: \(album.coverArtId ?? "nil")")
            return album.coverArtId
        }
        
        print("⚠️ Repo: Song found, but Album \(albumId) missing.")
        return nil
    }
}

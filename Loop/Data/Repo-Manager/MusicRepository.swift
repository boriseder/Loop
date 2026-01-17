//
//  MusicRepository.swift
//  Loop
//
//  FIXED: Added Artist Cache to transaction to ensure Artists are linked correctly.
//

import Foundation
import SwiftData
import OSLog

final class MusicRepository: Sendable {
    
    private let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.loopapp", category: "Repo")
    
    init(db: MusicDatabase) {
        self.modelContainer = db.container
    }
    
    // MARK: - Direct DB Reads
    
    nonisolated func getAlbums(offset: Int = 0, limit: Int = 100) async throws -> [AlbumDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<Loop.Album>(
                sortBy: [SortDescriptor(\.title, comparator: .localizedStandard)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
        }
    }
    
    nonisolated func getArtists(offset: Int = 0, limit: Int = 100) async throws -> [ArtistDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            // Debug print to see what the DB actually has
            let count = try? context.fetchCount(FetchDescriptor<Loop.Artist>())
            print("🔍 DEBUG: DB Artist Count: \(count ?? -1)")
            
            var descriptor = FetchDescriptor<Loop.Artist>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            
            return try context.fetch(descriptor).map { ArtistDTO(from: $0) }
        }
    }
    
    nonisolated func getGenres() async throws -> [GenreDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<Loop.Genre>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
            return try context.fetch(descriptor).map { GenreDTO(from: $0) }
        }
    }
    
    nonisolated func getAlbum(id: String) async throws -> AlbumDTO? {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Album> { $0.id == id }
            var descriptor = FetchDescriptor<Loop.Album>(predicate: predicate)
            descriptor.fetchLimit = 1
            guard let album = try context.fetch(descriptor).first else { return nil }
            return AlbumDTO(from: album)
        }
    }
    
    nonisolated func getArtist(id: String) async throws -> ArtistDTO? {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Artist> { $0.id == id }
            var descriptor = FetchDescriptor<Loop.Artist>(predicate: predicate)
            descriptor.fetchLimit = 1
            guard let artist = try context.fetch(descriptor).first else { return nil }
            return ArtistDTO(from: artist)
        }
    }
    
    nonisolated func getAlbums(forArtist artistId: String) async throws -> [AlbumDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Album> { $0.artistId == artistId }
            let descriptor = FetchDescriptor<Loop.Album>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.year, order: .reverse)]
            )
            return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
        }
    }
    
    nonisolated func getAlbums(forGenre genre: String) async throws -> [AlbumDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<Loop.Album>(
                sortBy: [SortDescriptor(\.title)]
            )
            let all = try context.fetch(descriptor)
            return all.filter { $0.genre == genre }.map { AlbumDTO(from: $0) }
        }
    }
    
    nonisolated func getSongs(for albumId: String) async throws -> [SongDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Song> { $0.albumId == albumId }
            let descriptor = FetchDescriptor<Loop.Song>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.trackNumber)]
            )
            return try context.fetch(descriptor).map { SongDTO(from: $0) }
        }
    }
    
    nonisolated func song(id: String) async throws -> SongDTO? {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Song> { $0.id == id }
            var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
            descriptor.fetchLimit = 1
            guard let song = try context.fetch(descriptor).first else { return nil }
            return SongDTO(from: song)
        }
    }
    
    nonisolated func search(query: String) async throws -> SearchResults {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return SearchResults() }
        
        return try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            
            let albumPred = #Predicate<Loop.Album> { $0.title.localizedStandardContains(cleanQuery) }
            var albumDesc = FetchDescriptor<Loop.Album>(predicate: albumPred, sortBy: [SortDescriptor(\.title)])
            albumDesc.fetchLimit = 10
            let albums = try context.fetch(albumDesc).map { AlbumDTO(from: $0) }
            
            let artistPred = #Predicate<Loop.Artist> { $0.name.localizedStandardContains(cleanQuery) }
            var artistDesc = FetchDescriptor<Loop.Artist>(predicate: artistPred, sortBy: [SortDescriptor(\.name)])
            artistDesc.fetchLimit = 5
            let artists = try context.fetch(artistDesc).map { ArtistDTO(from: $0) }
            
            let songPred = #Predicate<Loop.Song> { $0.title.localizedStandardContains(cleanQuery) }
            var songDesc = FetchDescriptor<Loop.Song>(predicate: songPred)
            songDesc.fetchLimit = 20
            let songs = try context.fetch(songDesc).map { SongDTO(from: $0) }
            
            return SearchResults(songs: songs, albums: albums, artists: artists)
        }
    }
    
    // MARK: - Writes
    
    nonisolated func saveAlbums(_ remoteAlbums: [RemoteAlbum]) async throws {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            // ✅ CACHE: Keeps track of artists created in this transaction
            var artistCache: [String: Loop.Artist] = [:]
            
            for remote in remoteAlbums {
                try saveOrUpdateAlbum(remote, in: context, artistCache: &artistCache)
            }
            try context.save()
        }
    }
    
    nonisolated func saveAlbumDetails(album: RemoteAlbumDetail, songs: [RemoteSong]) async throws {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            // Small scope, cache not strictly needed but good for consistency
            var artistCache: [String: Loop.Artist] = [:]
            
            let artist = try getOrCreateArtist(id: album.artistId, name: album.artist, in: context, cache: &artistCache)
            let albumEntity = try getOrCreateAlbum(id: album.id, from: album, artist: artist, in: context)
            albumEntity.coverArtId = album.coverArt
            
            for remoteSong in songs {
                try saveOrUpdateSong(remoteSong, album: albumEntity, artist: artist, in: context)
            }
            try context.save()
        }
    }
    
    nonisolated func saveGenres(_ remoteGenres: [RemoteGenre]) async throws {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            for rg in remoteGenres {
                guard !rg.value.isEmpty else { continue }
                let name = rg.value
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
            try context.save()
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveOrUpdateAlbum(_ remote: RemoteAlbum, in context: ModelContext, artistCache: inout [String: Loop.Artist]) throws {
        let albumId = remote.id
        let predicate = #Predicate<Loop.Album> { $0.id == albumId }
        var descriptor = FetchDescriptor<Loop.Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        // Ensure Artist Exists
        let artist = try getOrCreateArtist(id: remote.artistId, name: remote.artist, in: context, cache: &artistCache)
        
        if let existing = try? context.fetch(descriptor).first {
            existing.coverArtId = remote.coverArt
            existing.year = remote.year
            existing.genre = remote.genre
            // ✅ Link Artist if missing
            if existing.artist == nil || existing.artistId != remote.artistId {
                existing.artist = artist
            }
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
    
    private func getOrCreateAlbum(id: String, from remote: RemoteAlbumDetail? = nil, artist: Loop.Artist, in context: ModelContext) throws -> Loop.Album {
        let predicate = #Predicate<Loop.Album> { $0.id == id }
        var descriptor = FetchDescriptor<Loop.Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let newAlbum = Loop.Album(
            id: id,
            title: remote?.name ?? "Unknown Album",
            artistId: artist.id,
            coverArtId: remote?.coverArt,
            year: remote?.year,
            genre: remote?.genre
        )
        newAlbum.artist = artist
        context.insert(newAlbum)
        return newAlbum
    }
    
    private func saveOrUpdateSong(_ remote: RemoteSong, album: Loop.Album, artist: Loop.Artist, in context: ModelContext) throws {
        let songId = remote.id
        let predicate = #Predicate<Loop.Song> { $0.id == songId }
        var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            existing.title = remote.title
            existing.trackNumber = remote.track ?? 0
            existing.duration = TimeInterval(remote.duration ?? 0)
        } else {
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
            song.artist = artist
            context.insert(song)
        }
    }
    
    // ✅ Updated to use Cache + Context
    private func getOrCreateArtist(id: String, name: String, in context: ModelContext, cache: inout [String: Loop.Artist]) throws -> Loop.Artist {
        // 1. Check Local Cache (Fastest)
        if let cached = cache[id] {
            return cached
        }
        
        // 2. Check Database
        let predicate = #Predicate<Loop.Artist> { $0.id == id }
        var descriptor = FetchDescriptor<Loop.Artist>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            cache[id] = existing
            return existing
        }
        
        // 3. Create New
        let artist = Loop.Artist(id: id, name: name)
        context.insert(artist)
        cache[id] = artist
        return artist
    }
    
    private func withCancellationCheck<T>(_ operation: () throws -> T) throws -> T {
        try Task.checkCancellation()
        return try operation()
    }
}

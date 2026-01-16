//
//  MusicRepository.swift
//  Loop
//
//  FIXED: Removed MainActor, proper background context usage, cancellation support
//

import Foundation
import SwiftData
import OSLog

final class MusicRepository: Sendable {
    
    private let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.loopapp", category: "Repo")
    
    // Background context for async operations
    private let backgroundContext: ModelContext
    
    init(db: MusicDatabase) {
        self.modelContainer = db.container
        self.backgroundContext = ModelContext(db.container)
        backgroundContext.autosaveEnabled = false
    }
    
    // MARK: - Reads (All nonisolated, return value types)
    
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
    
    nonisolated func getSongs(for albumId: String) async throws -> [SongDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Song> { $0.albumId == albumId }
            let descriptor = FetchDescriptor<Loop.Song>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.trackNumber)]
            )
            
            let songs = try context.fetch(descriptor)
            return songs.map { SongDTO(from: $0) }
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
            
            let albums = try context.fetch(descriptor)
            return albums.map { AlbumDTO(from: $0) }
        }
    }
    
    nonisolated func getAlbums(forGenre genre: String, limit: Int = 500) async throws -> [AlbumDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let predicate = #Predicate<Loop.Album> {
                $0.genre?.localizedStandardContains(genre) ?? false
            }
            var descriptor = FetchDescriptor<Loop.Album>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.year, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            let albums = try context.fetch(descriptor)
            return albums.map { AlbumDTO(from: $0) }
        }
    }
    
    nonisolated func getAlbums(offset: Int = 0, limit: Int = 100) async throws -> [AlbumDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<Loop.Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            
            let albums = try context.fetch(descriptor)
            return albums.map { AlbumDTO(from: $0) }
        }
    }
    
    nonisolated func getArtists(offset: Int = 0, limit: Int = 100) async throws -> [ArtistDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<Loop.Artist>(sortBy: [SortDescriptor(\.name)])
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            
            let artists = try context.fetch(descriptor)
            return artists.map { ArtistDTO(from: $0) }
        }
    }
    
    nonisolated func getGenres() async throws -> [GenreDTO] {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<Loop.Genre>(sortBy: [SortDescriptor(\.name)])
            let genres = try context.fetch(descriptor)
            return genres.map { GenreDTO(from: $0) }
        }
    }
    
    nonisolated func search(query: String) async throws -> SearchResults {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanQuery.isEmpty else { return SearchResults() }
            
            // Songs
            let songPredicate = #Predicate<Loop.Song> { $0.title.localizedStandardContains(cleanQuery) }
            var songDesc = FetchDescriptor<Loop.Song>(predicate: songPredicate)
            songDesc.fetchLimit = 20
            let songs = try context.fetch(songDesc).map { SongDTO(from: $0) }
            
            // Albums
            let albumPredicate = #Predicate<Loop.Album> { $0.title.localizedStandardContains(cleanQuery) }
            var albumDesc = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
            albumDesc.fetchLimit = 10
            let albums = try context.fetch(albumDesc).map { AlbumDTO(from: $0) }
            
            // Artists
            let artistPredicate = #Predicate<Loop.Artist> { $0.name.localizedStandardContains(cleanQuery) }
            var artistDesc = FetchDescriptor<Loop.Artist>(predicate: artistPredicate)
            artistDesc.fetchLimit = 5
            let artists = try context.fetch(artistDesc).map { ArtistDTO(from: $0) }
            
            return SearchResults(songs: songs, albums: albums, artists: artists)
        }
    }
    
    // MARK: - Writes (Background context)
    
    nonisolated func saveAlbums(_ remoteAlbums: [RemoteAlbum]) async throws {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            
            for remote in remoteAlbums {
                try saveOrUpdateAlbum(remote, in: context)
            }
            
            try context.save()
        }
    }
    
    nonisolated func saveAlbumDetails(album: RemoteAlbumDetail, songs: [RemoteSong]) async throws {
        try await withCancellationCheck {
            let context = ModelContext(modelContainer)
            
            let artist = try getOrCreateArtist(id: album.artistId, name: album.artist, in: context)
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
    
    private func saveOrUpdateAlbum(_ remote: RemoteAlbum, in context: ModelContext) throws {
        let albumId = remote.id
        let predicate = #Predicate<Loop.Album> { $0.id == albumId }
        var descriptor = FetchDescriptor<Loop.Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            existing.coverArtId = remote.coverArt
            existing.year = remote.year
            existing.genre = remote.genre
        } else {
            let artist = try getOrCreateArtist(id: remote.artistId, name: remote.artist, in: context)
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
    
    private func getOrCreateArtist(id: String, name: String, in context: ModelContext) throws -> Loop.Artist {
        let predicate = #Predicate<Loop.Artist> { $0.id == id }
        var descriptor = FetchDescriptor<Loop.Artist>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let artist = Loop.Artist(id: id, name: name)
        context.insert(artist)
        return artist
    }
    
    // Helper to check cancellation
    private func withCancellationCheck<T>(_ operation: () throws -> T) throws -> T {
        try Task.checkCancellation()
        return try operation()
    }
}

// MARK: - DTOs (Value Types for Thread Safety)

struct SongDTO: Identifiable, Sendable {
    let id: String
    let title: String
    let trackNumber: Int
    let duration: TimeInterval
    let path: String
    let artistId: String
    let albumId: String
    let artistName: String?
    let albumTitle: String?
    let coverArtId: String?
    
    init(from song: Loop.Song) {
        self.id = song.id
        self.title = song.title
        self.trackNumber = song.trackNumber
        self.duration = song.duration
        self.path = song.path
        self.artistId = song.artistId
        self.albumId = song.albumId
        self.artistName = song.artist?.name
        self.albumTitle = song.album?.title
        self.coverArtId = song.album?.coverArtId
    }
}

struct AlbumDTO: Identifiable, Sendable {
    let id: String
    let title: String
    let artistId: String
    let artistName: String?
    let coverArtId: String?
    let year: Int?
    let genre: String?
    
    init(from album: Loop.Album) {
        self.id = album.id
        self.title = album.title
        self.artistId = album.artistId
        self.artistName = album.artist?.name
        self.coverArtId = album.coverArtId
        self.year = album.year
        self.genre = album.genre
    }
}

struct ArtistDTO: Identifiable, Sendable {
    let id: String
    let name: String
    
    init(from artist: Loop.Artist) {
        self.id = artist.id
        self.name = artist.name
    }
}

struct GenreDTO: Identifiable, Sendable {
    let name: String
    let albumCount: Int
    let songCount: Int
    
    var id: String { name }
    
    init(from genre: Loop.Genre) {
        self.name = genre.name
        self.albumCount = genre.albumCount
        self.songCount = genre.songCount
    }
}

struct SearchResults: Sendable {
    var songs: [SongDTO] = []
    var albums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
}

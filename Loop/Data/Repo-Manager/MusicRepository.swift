//
//  MusicRepository.swift
//  Loop
//
//  Focused on data access only - no sync, no caching
//

import Foundation
import SwiftData
import OSLog

@MainActor
final class MusicRepository {
    
    private let db: MusicDatabase
    private let logger = Logger(subsystem: "com.loopapp", category: "Repo")
    
    private var context: ModelContext {
        db.container.mainContext
    }
    
    init(db: MusicDatabase) {
        self.db = db
    }
    
    // MARK: - Reads
    
    func song(id: String) async -> Loop.Song? {
        let predicate = #Predicate<Loop.Song> { $0.id == id }
        var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    func getAlbum(id: String) -> Loop.Album? {
        let descriptor = FetchDescriptor<Loop.Album>(predicate: #Predicate<Loop.Album> { $0.id == id })
        return try? context.fetch(descriptor).first
    }
    
    func getSongs(for albumId: String) -> [Loop.Song] {
        let descriptor = FetchDescriptor<Loop.Song>(
            predicate: #Predicate<Loop.Song> { $0.albumId == albumId },
            sortBy: [SortDescriptor(\.trackNumber)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getArtist(id: String) -> Loop.Artist? {
        let descriptor = FetchDescriptor<Loop.Artist>(predicate: #Predicate<Loop.Artist> { $0.id == id })
        return try? context.fetch(descriptor).first
    }
    
    func getAlbums(forArtist artistId: String) -> [Loop.Album] {
        let predicate = #Predicate<Loop.Album> { $0.artistId == artistId }
        let descriptor = FetchDescriptor<Loop.Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getAlbums(forGenre genre: String, limit: Int = 500) async throws -> [Loop.Album] {
        let predicate = #Predicate<Loop.Album> {
            $0.genre?.localizedStandardContains(genre) ?? false
        }
        var descriptor = FetchDescriptor<Loop.Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func getAlbums(offset: Int = 0, limit: Int = 100) async throws -> [Loop.Album] {
        var descriptor = FetchDescriptor<Loop.Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func getArtists(offset: Int = 0, limit: Int = 100) async throws -> [Loop.Artist] {
        var descriptor = FetchDescriptor<Loop.Artist>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func getGenres() async throws -> [Loop.Genre] {
        return try context.fetch(FetchDescriptor<Loop.Genre>(sortBy: [SortDescriptor(\.name)]))
    }
    
    func getAlbumsNeedingCovers(limit: Int = 100) async -> [Loop.Album] {
        let predicate = #Predicate<Loop.Album> { $0.coverArtId != nil }
        var descriptor = FetchDescriptor<Loop.Album>(predicate: predicate)
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Search
    
    func search(query: String) -> SearchResults {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return SearchResults() }
        
        let songPredicate = #Predicate<Loop.Song> {
            $0.title.localizedStandardContains(cleanQuery)
        }
        var songDesc = FetchDescriptor<Loop.Song>(predicate: songPredicate)
        songDesc.fetchLimit = 20
        let songs = (try? context.fetch(songDesc)) ?? []
        
        let albumPredicate = #Predicate<Loop.Album> {
            $0.title.localizedStandardContains(cleanQuery)
        }
        var albumDesc = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
        albumDesc.fetchLimit = 10
        let albums = (try? context.fetch(albumDesc)) ?? []
        
        let artistPredicate = #Predicate<Loop.Artist> {
            $0.name.localizedStandardContains(cleanQuery)
        }
        var artistDesc = FetchDescriptor<Loop.Artist>(predicate: artistPredicate)
        artistDesc.fetchLimit = 5
        let artists = (try? context.fetch(artistDesc)) ?? []
        
        return SearchResults(songs: songs, albums: albums, artists: artists)
    }
    
    // MARK: - Writes
    
    func saveAlbums(_ remoteAlbums: [RemoteAlbum]) async throws {
        for remote in remoteAlbums {
            try saveOrUpdateAlbum(remote)
        }
        try context.save()
    }
    
    func saveAlbumWithSongs(album: RemoteAlbumDetail, songs: [RemoteSong]) async throws {
        // Ensure artist exists
        let artist = try getOrCreateArtist(id: album.artistId, name: album.artist)
        
        // Ensure album exists
        let albumEntity: Loop.Album
        if let existing = getAlbum(id: album.id) {
            albumEntity = existing
            albumEntity.coverArtId = album.coverArt
        } else {
            albumEntity = Loop.Album(
                id: album.id,
                title: album.name,
                artistId: album.artistId,
                coverArtId: album.coverArt,
                year: album.year,
                genre: album.genre
            )
            albumEntity.artist = artist
            context.insert(albumEntity)
        }
        
        // Save songs
        for remoteSong in songs {
            try saveOrUpdateSong(remoteSong, album: albumEntity, artist: artist)
        }
        
        try context.save()
    }
    
    func saveGenres(_ remoteGenres: [RemoteGenre]) async throws {
        for rg in remoteGenres {
            let name = rg.value
            guard !name.isEmpty else { continue }
            
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
    
    // MARK: - Private Helpers
    
    private func saveOrUpdateAlbum(_ remote: RemoteAlbum) throws {
        if let existing = getAlbum(id: remote.id) {
            existing.coverArtId = remote.coverArt
            existing.year = remote.year
            existing.genre = remote.genre
        } else {
            let artist = try getOrCreateArtist(id: remote.artistId, name: remote.artist)
            
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
    
    private func saveOrUpdateSong(_ remote: RemoteSong, album: Loop.Album, artist: Loop.Artist) throws {
        let predicate = #Predicate<Loop.Song> { $0.id == remote.id }
        let descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        
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
    
    private func getOrCreateArtist(id: String, name: String) throws -> Loop.Artist {
        if let existing = getArtist(id: id) {
            return existing
        }
        
        let artist = Loop.Artist(id: id, name: name)
        context.insert(artist)
        return artist
    }
}

// MARK: - Search Results

struct SearchResults {
    var songs: [Loop.Song] = []
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
}

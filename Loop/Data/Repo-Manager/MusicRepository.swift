//
//  MusicRepository.swift
//  Loop
//
//  Fixed: SwiftData Predicate Strictness & SearchResults Scope
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
    
    func song(id: String) -> Loop.Song? {
        let targetId = id
        let predicate = #Predicate<Loop.Song> { song in song.id == targetId }
        var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    func getAlbum(id: String) -> Loop.Album? {
        let targetId = id
        let descriptor = FetchDescriptor<Loop.Album>(predicate: #Predicate<Loop.Album> { $0.id == targetId })
        return try? context.fetch(descriptor).first
    }
    
    func getSongs(for albumId: String) -> [Loop.Song] {
        let targetId = albumId
        let descriptor = FetchDescriptor<Loop.Song>(
            predicate: #Predicate<Loop.Song> { $0.albumId == targetId },
            sortBy: [SortDescriptor(\.trackNumber)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getArtist(id: String) -> Loop.Artist? {
        let targetId = id
        let descriptor = FetchDescriptor<Loop.Artist>(predicate: #Predicate<Loop.Artist> { $0.id == targetId })
        return try? context.fetch(descriptor).first
    }

    func getAlbums(forArtist artistId: String) -> [Loop.Album] {
        let targetId = artistId
        let predicate = #Predicate<Loop.Album> { $0.artistId == targetId }
        let descriptor = FetchDescriptor<Loop.Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getAlbums(forGenre genre: String, limit: Int = 500) throws -> [Loop.Album] {
        let targetGenre = genre
        let predicate = #Predicate<Loop.Album> {
            $0.genre?.localizedStandardContains(targetGenre) ?? false
        }
        var descriptor = FetchDescriptor<Loop.Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func getAlbums(offset: Int = 0, limit: Int = 100) throws -> [Loop.Album] {
        var descriptor = FetchDescriptor<Loop.Album>(sortBy: [SortDescriptor(\.year, order: .reverse)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func getArtists(offset: Int = 0, limit: Int = 100) throws -> [Loop.Artist] {
        var descriptor = FetchDescriptor<Loop.Artist>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func getGenres() throws -> [Loop.Genre] {
        return try context.fetch(FetchDescriptor<Loop.Genre>(sortBy: [SortDescriptor(\.name)]))
    }
    
    func getAlbumsNeedingCovers(limit: Int = 100) -> [Loop.Album] {
        let predicate = #Predicate<Loop.Album> { $0.coverArtId != nil }
        var descriptor = FetchDescriptor<Loop.Album>(predicate: predicate)
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getArtistWithAlbums(id: String) throws -> (artist: Loop.Artist?, albums: [Loop.Album]) {
        let artist = getArtist(id: id)
        let albums = getAlbums(forArtist: id)
        return (artist, albums)
    }
    
    func getLocalAlbum(id: String) -> Loop.Album? { getAlbum(id: id) }
    func getLocalSongs(for albumId: String) -> [Loop.Song] { getSongs(for: albumId) }
    
    // MARK: - Search
    
    func search(query: String) -> SearchResults {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return SearchResults() }
        
        let targetQuery = cleanQuery
        
        // Songs
        let songPredicate = #Predicate<Loop.Song> { $0.title.localizedStandardContains(targetQuery) }
        var songDesc = FetchDescriptor<Loop.Song>(predicate: songPredicate)
        songDesc.fetchLimit = 20
        let songs = (try? context.fetch(songDesc)) ?? []
        
        // Albums
        let albumPredicate = #Predicate<Loop.Album> { $0.title.localizedStandardContains(targetQuery) }
        var albumDesc = FetchDescriptor<Loop.Album>(predicate: albumPredicate)
        albumDesc.fetchLimit = 10
        let albums = (try? context.fetch(albumDesc)) ?? []
        
        // Artists
        let artistPredicate = #Predicate<Loop.Artist> { $0.name.localizedStandardContains(targetQuery) }
        var artistDesc = FetchDescriptor<Loop.Artist>(predicate: artistPredicate)
        artistDesc.fetchLimit = 5
        let artists = (try? context.fetch(artistDesc)) ?? []
        
        return SearchResults(songs: songs, albums: albums, artists: artists)
    }

    // MARK: - Writes
    
    func saveAlbums(_ remoteAlbums: [RemoteAlbum]) throws {
        for remote in remoteAlbums {
            try saveOrUpdateAlbum(remote)
        }
        try context.save()
    }
    
    func saveAlbumDetails(album: RemoteAlbumDetail, songs: [RemoteSong]) throws {
        let artist = try getOrCreateArtist(id: album.artistId, name: album.artist)
        let albumEntity = try getOrCreateAlbum(id: album.id, from: album, artist: artist)
        albumEntity.coverArtId = album.coverArt
        
        for remoteSong in songs {
            try saveOrUpdateSong(remoteSong, album: albumEntity, artist: artist)
        }
        try context.save()
    }
    
    func saveGenres(_ remoteGenres: [RemoteGenre]) throws {
        for rg in remoteGenres {
            let name = rg.value
            guard !name.isEmpty else { continue }
            let targetName = name
            let predicate = #Predicate<Loop.Genre> { $0.name == targetName }
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
    
    private func saveOrUpdateAlbum(_ remote: RemoteAlbum) throws {
        if let existing = getAlbum(id: remote.id) {
            existing.coverArtId = remote.coverArt
            existing.year = remote.year
            existing.genre = remote.genre
        } else {
            let artist = try getOrCreateArtist(id: remote.artistId, name: remote.artist)
            let newAlbum = Loop.Album(id: remote.id, title: remote.name, artistId: remote.artistId, coverArtId: remote.coverArt, year: remote.year, genre: remote.genre)
            newAlbum.artist = artist
            context.insert(newAlbum)
        }
    }
    
    private func getOrCreateAlbum(id: String, from remote: RemoteAlbumDetail? = nil, artist: Loop.Artist) throws -> Loop.Album {
        if let existing = getAlbum(id: id) { return existing }
        let newAlbum = Loop.Album(id: id, title: remote?.name ?? "Unknown Album", artistId: artist.id, coverArtId: remote?.coverArt, year: remote?.year, genre: remote?.genre)
        newAlbum.artist = artist
        context.insert(newAlbum)
        return newAlbum
    }
    
    private func saveOrUpdateSong(_ remote: RemoteSong, album: Loop.Album, artist: Loop.Artist) throws {
        // ✅ FIX: Capture the primitive String ID in a local variable.
        // Accessing 'remote.id' inside the #Predicate closure causes the compiler
        // to try and capture the 'RemoteSong' struct, which fails SwiftData verification.
        let targetId = remote.id
        
        let predicate = #Predicate<Loop.Song> { song in
            song.id == targetId
        }
        
        var descriptor = FetchDescriptor<Loop.Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            existing.title = remote.title
            existing.trackNumber = remote.track ?? 0
            existing.duration = TimeInterval(remote.duration ?? 0)
        } else {
            let song = Loop.Song(
                id: remote.id, // accessing remote.id here is fine (outside predicate)
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
        if let existing = getArtist(id: id) { return existing }
        let artist = Loop.Artist(id: id, name: name)
        context.insert(artist)
        return artist
    }
}

// ✅ FIX: Defined at file scope
struct SearchResults {
    var songs: [Loop.Song] = []
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
}

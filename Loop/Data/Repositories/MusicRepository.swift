import Foundation
import SwiftData
import OSLog

@MainActor
final class MusicRepository {
    private let container: ModelContainer
    private let context: ModelContext
    
    init(db: MusicDatabase) {
        self.container = db.container
        self.context = db.container.mainContext
    }
    
    // MARK: - Reads (Optimized for UI)
    
    func getAlbums(offset: Int = 0, limit: Int = 100) throws -> [AlbumDTO] {
        var descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        
        return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
    }
    
    func getArtists(offset: Int = 0, limit: Int = 100) throws -> [ArtistDTO] {
        var descriptor = FetchDescriptor<Artist>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        
        return try context.fetch(descriptor).map { ArtistDTO(from: $0) }
    }
    
    func getGenres() throws -> [GenreDTO] {
        let descriptor = FetchDescriptor<Genre>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try context.fetch(descriptor).map { GenreDTO(from: $0) }
    }
    
    func getAlbum(id: String) throws -> AlbumDTO? {
        let predicate = #Predicate<Album> { $0.id == id }
        var descriptor = FetchDescriptor<Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { AlbumDTO(from: $0) }
    }
    
    func getArtist(id: String) throws -> ArtistDTO? {
        let predicate = #Predicate<Artist> { $0.id == id }
        var descriptor = FetchDescriptor<Artist>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { ArtistDTO(from: $0) }
    }
    
    func getAlbums(forArtist artistId: String) throws -> [AlbumDTO] {
        let predicate = #Predicate<Album> { $0.artistId == artistId }
        // Sort by year descending (newest first)
        let descriptor = FetchDescriptor<Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
    }
    
    func getAlbums(forGenre genre: String) throws -> [AlbumDTO] {
        // Note: String comparisons in Predicates are case-sensitive by default in SwiftData
        let predicate = #Predicate<Album> { $0.genre == genre }
        let descriptor = FetchDescriptor<Album>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
    }
    
    func getSongs(for albumId: String) throws -> [SongDTO] {
        let predicate = #Predicate<Song> { $0.albumId == albumId }
        let descriptor = FetchDescriptor<Song>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.trackNumber, order: .forward)]
        )
        return try context.fetch(descriptor).map { SongDTO(from: $0) }
    }
    
    func getSong(id: String) throws -> SongDTO? {
        let predicate = #Predicate<Song> { $0.id == id }
        var descriptor = FetchDescriptor<Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { SongDTO(from: $0) }
    }
    
    func search(query: String) throws -> (songs: [SongDTO], albums: [AlbumDTO], artists: [ArtistDTO]) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return ([], [], []) }
        
        // Albums
        let albumPred = #Predicate<Album> { $0.title.localizedStandardContains(cleanQuery) }
        var albumDesc = FetchDescriptor<Album>(predicate: albumPred, sortBy: [SortDescriptor(\.title)])
        albumDesc.fetchLimit = 10
        let albums = try context.fetch(albumDesc).map { AlbumDTO(from: $0) }
        
        // Artists
        let artistPred = #Predicate<Artist> { $0.name.localizedStandardContains(cleanQuery) }
        var artistDesc = FetchDescriptor<Artist>(predicate: artistPred, sortBy: [SortDescriptor(\.name)])
        artistDesc.fetchLimit = 5
        let artists = try context.fetch(artistDesc).map { ArtistDTO(from: $0) }
        
        // Songs
        let songPred = #Predicate<Song> { $0.title.localizedStandardContains(cleanQuery) }
        var songDesc = FetchDescriptor<Song>(predicate: songPred, sortBy: [SortDescriptor(\.title)])
        songDesc.fetchLimit = 20
        let songs = try context.fetch(songDesc).map { SongDTO(from: $0) }
        
        return (songs, albums, artists)
    }
}

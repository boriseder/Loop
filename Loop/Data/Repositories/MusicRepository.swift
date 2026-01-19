import Foundation
import SwiftData
import OSLog

// MARK: - Repository (NO @MainActor - runs on background)
final class MusicRepository: Sendable {
    private let container: ModelContainer
    private let logger = Logger(subsystem: "com.loopapp", category: "Repo")
    
    init(db: MusicDatabase) {
        self.container = db.container
    }
    
    // MARK: - Context Helper
    @MainActor
    private var mainContext: ModelContext {
        container.mainContext
    }
    
    private func backgroundContext() -> ModelContext {
        ModelContext(container)
    }
    
    // MARK: - Reads (Can be called from any context)
    
    func getAlbums(offset: Int = 0, limit: Int = 100) async throws -> [AlbumDTO] {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<Album>(
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            
            return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
        }.value
    }
    
    func getArtists(offset: Int = 0, limit: Int = 100) async throws -> [ArtistDTO] {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<Artist>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            
            return try context.fetch(descriptor).map { ArtistDTO(from: $0) }
        }.value
    }
    
    func getGenres() async throws -> [GenreDTO] {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Genre>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            return try context.fetch(descriptor).map { GenreDTO(from: $0) }
        }.value
    }
    
    func getAlbum(id: String) async throws -> AlbumDTO? {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let predicate = #Predicate<Album> { $0.id == id }
            var descriptor = FetchDescriptor<Album>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map { AlbumDTO(from: $0) }
        }.value
    }
    
    func getArtist(id: String) async throws -> ArtistDTO? {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let predicate = #Predicate<Artist> { $0.id == id }
            var descriptor = FetchDescriptor<Artist>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map { ArtistDTO(from: $0) }
        }.value
    }
    
    func getAlbums(forArtist artistId: String) async throws -> [AlbumDTO] {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let predicate = #Predicate<Album> { $0.artistId == artistId }
            let descriptor = FetchDescriptor<Album>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.year, order: .reverse)]
            )
            return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
        }.value
    }
    
    func getAlbums(forGenre genre: String) async throws -> [AlbumDTO] {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let predicate = #Predicate<Album> { $0.genre == genre }
            let descriptor = FetchDescriptor<Album>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
            return try context.fetch(descriptor).map { AlbumDTO(from: $0) }
        }.value
    }
    
    func getSongs(for albumId: String) async throws -> [SongDTO] {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let predicate = #Predicate<Song> { $0.albumId == albumId }
            let descriptor = FetchDescriptor<Song>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.trackNumber, order: .forward)]
            )
            return try context.fetch(descriptor).map { SongDTO(from: $0) }
        }.value
    }
    
    func getSong(id: String) async throws -> SongDTO? {
        try await Task.detached { [container] in
            let context = ModelContext(container)
            let predicate = #Predicate<Song> { $0.id == id }
            var descriptor = FetchDescriptor<Song>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map { SongDTO(from: $0) }
        }.value
    }
    
    func search(query: String) async throws -> (songs: [SongDTO], albums: [AlbumDTO], artists: [ArtistDTO]) {
        try await Task.detached { [container] in
            let context = ModelContext(container)
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
        }.value
    }
}

import Foundation
import SwiftData
import OSLog

// MARK: - Background Sync Actor (Proper isolation)
@ModelActor
actor BackgroundSyncActor {
    private let logger = Logger(subsystem: "com.loopapp", category: "SyncWorker")
    
    func saveAlbums(_ remoteAlbums: [RemoteAlbum]) throws {
        var artistCache: [String: Artist] = [:]
        
        for remote in remoteAlbums {
            let artist = try getOrCreateArtist(id: remote.artistId, name: remote.artist, cache: &artistCache)
            let _ = try getOrCreateAlbum(from: remote, artist: artist)
        }
        try modelContext.save()
    }
    
    func saveGenres(_ remoteGenres: [RemoteGenre]) throws {
        for rg in remoteGenres {
            guard !rg.value.isEmpty else { continue }
            let name = rg.value
            let predicate = #Predicate<Genre> { $0.name == name }
            var descriptor = FetchDescriptor<Genre>(predicate: predicate)
            descriptor.fetchLimit = 1
            
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.albumCount = rg.albumCount
                existing.songCount = rg.songCount
            } else {
                modelContext.insert(Genre(name: rg.value, albumCount: rg.albumCount, songCount: rg.songCount))
            }
        }
        try modelContext.save()
    }
    
    func saveAlbumDetails(details: RemoteAlbumDetail, songs: [RemoteSong]) throws {
        var artistCache: [String: Artist] = [:]
        let artist = try getOrCreateArtist(id: details.artistId, name: details.artist, cache: &artistCache)
        
        let album = try getOrCreateAlbum(from: details, artist: artist)
        album.coverArtId = details.coverArt
        
        for remoteSong in songs {
            try saveOrUpdateSong(remoteSong, album: album, artist: artist)
        }
        try modelContext.save()
    }
    
    // MARK: - Private Helpers
    
    private func getOrCreateArtist(id: String, name: String, cache: inout [String: Artist]) throws -> Artist {
        if let cached = cache[id] { return cached }
        let predicate = #Predicate<Artist> { $0.id == id }
        var descriptor = FetchDescriptor<Artist>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            cache[id] = existing
            return existing
        }
        let newArtist = Artist(id: id, name: name)
        modelContext.insert(newArtist)
        cache[id] = newArtist
        return newArtist
    }
    
    private func getOrCreateAlbum(from remote: RemoteAlbum, artist: Artist) throws -> Album {
        let id = remote.id
        let predicate = #Predicate<Album> { $0.id == id }
        var descriptor = FetchDescriptor<Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.coverArtId = remote.coverArt
            existing.year = remote.year
            existing.genre = remote.genre
            if existing.artist?.id != artist.id { existing.artist = artist }
            return existing
        }
        let newAlbum = Album(id: id, title: remote.name, artistId: remote.artistId, coverArtId: remote.coverArt, year: remote.year, genre: remote.genre)
        newAlbum.artist = artist
        modelContext.insert(newAlbum)
        return newAlbum
    }
    
    private func getOrCreateAlbum(from remote: RemoteAlbumDetail, artist: Artist) throws -> Album {
        let id = remote.id
        let predicate = #Predicate<Album> { $0.id == id }
        var descriptor = FetchDescriptor<Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let newAlbum = Album(id: id, title: remote.name, artistId: remote.artistId, coverArtId: remote.coverArt, year: remote.year, genre: remote.genre)
        newAlbum.artist = artist
        modelContext.insert(newAlbum)
        return newAlbum
    }
    
    private func saveOrUpdateSong(_ remote: RemoteSong, album: Album, artist: Artist) throws {
        let id = remote.id
        let predicate = #Predicate<Song> { $0.id == id }
        var descriptor = FetchDescriptor<Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.title = remote.title
            existing.trackNumber = remote.track ?? 0
            existing.duration = TimeInterval(remote.duration ?? 0)
        } else {
            let song = Song(id: id, title: remote.title, trackNumber: remote.track ?? 0, duration: TimeInterval(remote.duration ?? 0), path: remote.path ?? "", artistId: artist.id, albumId: album.id)
            song.album = album
            song.artist = artist
            modelContext.insert(song)
        }
    }
}

// MARK: - Sync Manager (MainActor ONLY for @Observable state)
@Observable @MainActor
final class SyncManager {
    // MARK: - Published State
    private(set) var progress = SyncProgress(phase: .idle)
    
    var isSyncing: Bool { progress.isActive }
    var statusMessage: String? {
        progress.isActive ? progress.displayText : nil
    }
    
    // MARK: - Private
    private let client: NavidromeClient
    private let container: ModelContainer
    private let logger = Logger(subsystem: "com.loopapp", category: "Sync")
    
    private var syncTask: Task<Void, Never>?
    
    init(client: NavidromeClient, container: ModelContainer) {
        self.client = client
        self.container = container
    }
    
    // MARK: - Public API
    func startSmartSync(force: Bool = false) {
        // Cancel existing sync
        syncTask?.cancel()
        
        // Start new sync in background
        syncTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performSync()
        }
    }
    
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        Task { @MainActor in
            self.progress = SyncProgress(phase: .idle)
        }
    }
    
    // MARK: - Background Sync Logic
    private func performSync() async {
        await updateProgress(.albums(current: 0, total: 0))
        
        do {
            let worker = BackgroundSyncActor(modelContainer: container)
            
            // 1. Fetch Albums (paginated)
            var offset = 0
            let pageSize = 200
            var totalAlbums = 0
            var hasMore = true
            
            while hasMore && !Task.isCancelled {
                let params = ["type": "newest", "offset": "\(offset)", "size": "\(pageSize)"]
                let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: params)
                
                if let albums = response.subsonicResponse.albumList2?.album, !albums.isEmpty {
                    try await worker.saveAlbums(albums)
                    totalAlbums += albums.count
                    offset += pageSize
                    
                    await updateProgress(.albums(current: totalAlbums, total: totalAlbums + 100))
                    
                    if albums.count < pageSize { hasMore = false }
                } else {
                    hasMore = false
                }
            }
            
            guard !Task.isCancelled else {
                await updateProgress(.idle)
                return
            }
            
            // 2. Fetch Genres
            await updateProgress(.genres)
            let genreResponse: SubsonicGenresResponse = try await client.fetch("getGenres")
            if let genres = genreResponse.subsonicResponse.genres?.genre {
                try await worker.saveGenres(genres)
            }
            
            guard !Task.isCancelled else {
                await updateProgress(.idle)
                return
            }
            
            // 3. Complete
            await updateProgress(.complete)
            logger.info("Sync completed: \(totalAlbums) albums")
            
            // Auto-clear after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            await updateProgress(.idle)
            
        } catch {
            guard !Task.isCancelled else {
                await updateProgress(.idle)
                return
            }
            
            logger.error("Sync failed: \(error.localizedDescription)")
            await updateProgress(.failed(error: error.localizedDescription))
            
            // Auto-clear error after 5 seconds
            try? await Task.sleep(for: .seconds(5))
            await updateProgress(.idle)
        }
    }
    
    @MainActor
    private func updateProgress(_ phase: SyncProgress.Phase) {
        self.progress = SyncProgress(phase: phase)
    }
    
    // MARK: - Album Detail Sync
    func syncAlbumDetails(_ albumId: String) async throws {
        let worker = BackgroundSyncActor(modelContainer: container)
        
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        guard let details = response.subsonicResponse.album,
              let songs = response.subsonicResponse.album?.song else {
            return
        }
        
        try await worker.saveAlbumDetails(details: details, songs: songs)
    }
}

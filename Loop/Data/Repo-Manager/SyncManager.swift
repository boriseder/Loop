//
//  SyncManager.swift
//  Loop
//
//  Responsibility: Orchestrate Network -> DB Sync
//

import Foundation
import OSLog

enum SyncError: Error {
    case invalidResponse
    case networkError(Error)
}

@MainActor
final class SyncManager {
    
    private let repo: MusicRepository
    private let client: NavidromeClient
    private let cache: CoverArtCache
    private let logger = Logger(subsystem: "com.loopapp", category: "Sync")
    
    private(set) var isSyncing = false
    
    init(repo: MusicRepository, client: NavidromeClient, cache: CoverArtCache) {
        self.repo = repo
        self.client = client
        self.cache = cache
    }
    
    func performSmartSync() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        logger.info("🔄 Starting smart sync")
        
        do {
            try await syncAlbumPage(type: "newest", offset: 0, size: 50)
            try await syncAlbumPage(type: "alphabeticalByName", offset: 0, size: 100)
            try await syncGenres()
            await prefetchCovers()
            
            logger.info("✅ Smart sync complete")
        } catch {
            logger.error("❌ Sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func syncAlbumPage(type: String, offset: Int, size: Int) async throws {
        let params = ["type": type, "offset": String(offset), "size": String(size)]
        let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: params)
        
        guard let albums = response.subsonicResponse.albumList2?.album else { return }
        try repo.saveAlbums(albums)
    }
    
    private func syncGenres() async throws {
        let response: SubsonicGenresResponse = try await client.fetch("getGenres")
        guard let genres = response.subsonicResponse.genres?.genre else { return }
        try repo.saveGenres(genres)
    }
    
    func syncAlbumDetails(albumId: String) async throws {
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        
        guard let details = response.subsonicResponse.album,
              let remoteSongs = details.song else {
            throw SyncError.invalidResponse
        }
        
        try repo.saveAlbumDetails(album: details, songs: remoteSongs)
        
        if let coverId = details.coverArt {
            // ✅ FIX: Explicitly ignore result
            Task { _ = await cache.downloadCover(id: coverId) }
        }
    }
    
    private func prefetchCovers() async {
        let albums = repo.getAlbumsNeedingCovers(limit: 100)
        
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            for album in albums {
                guard let coverId = album.coverArtId else { continue }
                if activeCount >= 5 {
                    await group.next()
                    activeCount -= 1
                }
                group.addTask {
                    _ = await self.cache.downloadCover(id: coverId)
                }
                activeCount += 1
            }
        }
    }
}

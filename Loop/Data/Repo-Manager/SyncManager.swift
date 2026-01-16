//
//  SyncManager.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  SyncManager.swift
//  Loop
//
//  Handles all sync operations separately from repository
//

import Foundation
import OSLog

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
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        logger.info("🔄 Starting smart sync")
        
        do {
            // 1. Sync newest albums (page 1)
            try await syncAlbumPage(type: "newest", offset: 0, size: 50)
            
            // 2. Sync alphabetical albums (first page only to avoid overwhelming)
            try await syncAlbumPage(type: "alphabeticalByName", offset: 0, size: 100)
            
            // 3. Sync genres
            try await syncGenres()
            
            // 4. Prefetch cover art (limited concurrency)
            await prefetchCovers()
            
            logger.info("✅ Smart sync complete")
            
        } catch {
            logger.error("❌ Sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func syncAlbumPage(type: String, offset: Int, size: Int) async throws {
        let params = [
            "type": type,
            "offset": String(offset),
            "size": String(size)
        ]
        
        let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: params)
        
        guard let albums = response.subsonicResponse.albumList2?.album else {
            return
        }
        
        try await repo.saveAlbums(albums)
        logger.info("📦 Synced \(albums.count) albums (type: \(type), offset: \(offset))")
    }
    
    private func syncGenres() async throws {
        let response: SubsonicGenresResponse = try await client.fetch("getGenres")
        guard let genres = response.subsonicResponse.genres?.genre else {
            return
        }
        
        try await repo.saveGenres(genres)
        logger.info("🎵 Synced \(genres.count) genres")
    }
    
    private func prefetchCovers() async {
        let albumsNeedingCovers = await repo.getAlbumsNeedingCovers(limit: 100)
        
        logger.info("🎨 Prefetching covers for \(albumsNeedingCovers.count) albums")
        
        // Limit concurrent downloads to avoid overwhelming the server
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            let maxConcurrent = 5
            
            for album in albumsNeedingCovers {
                guard let coverId = album.coverArtId else { continue }
                
                // Wait if we're at max concurrency
                while activeCount >= maxConcurrent {
                    await group.next()
                    activeCount -= 1
                }
                
                group.addTask {
                    await self.cache.downloadCover(id: coverId)
                }
                activeCount += 1
            }
        }
        
        logger.info("✅ Cover prefetch complete")
    }
    
    func syncAlbumDetails(albumId: String) async throws {
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        
        guard let details = response.subsonicResponse.album,
              let remoteSongs = details.song else {
            throw SyncError.invalidResponse
        }
        
        try await repo.saveAlbumWithSongs(album: details, songs: remoteSongs)
        
        // Download cover if needed
        if let coverId = details.coverArt {
            await cache.downloadCover(id: coverId)
        }
    }
}

enum SyncError: LocalizedError {
    case invalidResponse
    case alreadyInProgress
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received invalid data from server"
        case .alreadyInProgress:
            return "Sync already in progress"
        }
    }
}
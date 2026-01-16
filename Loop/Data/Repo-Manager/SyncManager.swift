//
//  SyncManager.swift
//  Loop
//
//  FIXED: Progress reporting for UI
//

import Foundation
import OSLog

enum SyncError: Error {
    case invalidResponse
    case networkError(Error)
    case cancelled
}

actor SyncManager {
    
    private let repo: MusicRepository
    private let client: NavidromeClient
    private let cache: CoverArtCache
    private let logger = Logger(subsystem: "com.loopapp", category: "Sync")
    
    private var isSyncing = false
    private var syncTask: Task<Void, Error>?
    
    // ✅ NEW: Progress callback with proper isolation
    private var progressCallback: (@Sendable @MainActor (SyncProgress) -> Void)?
    
    init(repo: MusicRepository, client: NavidromeClient, cache: CoverArtCache) {
        self.repo = repo
        self.client = client
        self.cache = cache
    }
    
    // ✅ NEW: Setter for progress callback
    func setProgressCallback(_ callback: @escaping @Sendable @MainActor (SyncProgress) -> Void) {
        self.progressCallback = callback
    }
    
    func performSmartSync() async throws {
        // Cancel any existing sync
        syncTask?.cancel()
        
        guard !isSyncing else {
            throw SyncError.cancelled
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        logger.info("🔄 Starting FULL offline sync")
        
        syncTask = Task {
            // 1. Sync ALL albums progressively
            try Task.checkCancellation()
            var offset = 0
            let pageSize = 100
            var hasMore = true
            var totalAlbums = 0
            
            logger.info("📚 Syncing all albums...")
            while hasMore {
                try Task.checkCancellation()
                
                let albumCount = try await syncAlbumPage(type: "newest", offset: offset, size: pageSize)
                totalAlbums += albumCount
                
                // ✅ Report progress
                await reportProgress(.albums(current: totalAlbums, total: max(totalAlbums, 500)))
                
                if albumCount < pageSize {
                    hasMore = false
                } else {
                    offset += pageSize
                }
                
                logger.info("Synced \(totalAlbums) albums so far...")
            }
            
            logger.info("✅ Synced \(totalAlbums) total albums")
            
            // 2. Sync genres
            try Task.checkCancellation()
            await reportProgress(.genres)
            try await syncGenres()
            logger.info("✅ Synced genres")
            
            // 3. Download ALL cover art for ALL albums
            try Task.checkCancellation()
            await downloadAllCovers(totalAlbums: totalAlbums)
            
            // 4. Complete
            await reportProgress(.complete)
        }
        
        do {
            try await syncTask?.value
            logger.info("✅ FULL offline sync complete - app is ready for offline use")
        } catch is CancellationError {
            logger.info("Sync cancelled")
            await reportProgress(.idle)
            throw SyncError.cancelled
        } catch {
            logger.error("❌ Sync failed: \(error.localizedDescription)")
            await reportProgress(.failed(error: error.localizedDescription))
            throw error
        }
    }
    
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
    }
    
    private func syncAlbumPage(type: String, offset: Int, size: Int) async throws -> Int {
        let params = ["type": type, "offset": String(offset), "size": String(size)]
        let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: params)
        
        guard let albums = response.subsonicResponse.albumList2?.album else { return 0 }
        try await repo.saveAlbums(albums)
        return albums.count
    }
    
    private func syncGenres() async throws {
        let response: SubsonicGenresResponse = try await client.fetch("getGenres")
        guard let genres = response.subsonicResponse.genres?.genre else { return }
        try await repo.saveGenres(genres)
    }
    
    func syncAlbumDetails(albumId: String) async throws {
        let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
        
        guard let details = response.subsonicResponse.album,
              let remoteSongs = details.song else {
            throw SyncError.invalidResponse
        }
        
        try await repo.saveAlbumDetails(album: details, songs: remoteSongs)
        
        if let coverId = details.coverArt {
            Task {
                await cache.downloadCover(id: coverId)
            }
        }
    }
    
    private func downloadAllCovers(totalAlbums: Int) async {
        logger.info("🖼️ Starting FULL cover download for offline use...")
        
        do {
            // Get ALL albums from database
            var allAlbums: [AlbumDTO] = []
            var offset = 0
            let pageSize = 500
            var hasMore = true
            
            while hasMore {
                let batch = try await repo.getAlbums(offset: offset, limit: pageSize)
                allAlbums.append(contentsOf: batch)
                
                if batch.count < pageSize {
                    hasMore = false
                } else {
                    offset += pageSize
                }
            }
            
            let albumsWithCovers = allAlbums.filter { $0.coverArtId != nil }
            logger.info("Found \(albumsWithCovers.count) albums with covers - downloading ALL")
            
            // Download ALL covers with concurrency limit
            await withTaskGroup(of: Void.self) { group in
                var downloaded = 0
                let maxConcurrent = 10
                var activeCount = 0
                
                for album in albumsWithCovers {
                    guard let coverId = album.coverArtId else { continue }
                    
                    // Wait if at capacity
                    if activeCount >= maxConcurrent {
                        await group.next()
                        activeCount -= 1
                        downloaded += 1
                        
                        // ✅ Report progress every 10 covers
                        if downloaded % 10 == 0 {
                            await reportProgress(.covers(current: downloaded, total: albumsWithCovers.count))
                        }
                    }
                    
                    group.addTask {
                        await self.cache.downloadCover(id: coverId, size: 300)
                    }
                    activeCount += 1
                }
                
                // Wait for remaining tasks
                while activeCount > 0 {
                    await group.next()
                    activeCount -= 1
                    downloaded += 1
                }
                
                logger.info("✅ Downloaded ALL \(downloaded) covers - app is fully offline ready")
            }
            
        } catch {
            logger.error("Cover download failed: \(error)")
        }
    }
    
    // ✅ NEW: Progress reporting helper
    private func reportProgress(_ phase: SyncProgress.Phase) async {
        let progress = SyncProgress(phase: phase)
        if let callback = progressCallback {
            await callback(progress)
        }
    }
}

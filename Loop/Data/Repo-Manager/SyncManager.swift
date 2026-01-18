//
//  SyncManager.swift
//  Loop
//
//  FIXED: Logger interpolation error resolved
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
    
    private var hasCompletedFullSync = false
    
    private var progressCallback: (@Sendable @MainActor (SyncProgress) -> Void)?
    
    init(repo: MusicRepository, client: NavidromeClient, cache: CoverArtCache) {
        self.repo = repo
        self.client = client
        self.cache = cache
        hasCompletedFullSync = UserDefaults.standard.bool(forKey: "loop.sync.completed")
    }
    
    func setProgressCallback(_ callback: @escaping @Sendable @MainActor (SyncProgress) -> Void) {
        self.progressCallback = callback
    }
    
    func performSmartSync(force: Bool = false) async throws {
        if !force && hasCompletedFullSync {
            logger.info("⏭️ Full sync already completed, skipping")
            return
        }
        
        syncTask?.cancel()
        
        guard !isSyncing else {
            throw SyncError.cancelled
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // ✅ FIXED: String interpolation
        logger.info("\(force ? "⚠️ FORCE Sync requested" : "🔄 Starting FULL offline sync")")
        
        syncTask = Task {
            var offset = 0
            let pageSize = 100
            var hasMore = true
            var totalAlbums = 0
            
            logger.info("📚 Syncing all albums...")
            while hasMore {
                try Task.checkCancellation()
                
                let albumCount = try await syncAlbumPage(type: "newest", offset: offset, size: pageSize)
                totalAlbums += albumCount
                
                await reportProgress(.albums(current: totalAlbums, total: max(totalAlbums, 500)))
                
                if albumCount < pageSize {
                    hasMore = false
                } else {
                    offset += pageSize
                }
                
                logger.info("Synced \(totalAlbums) albums so far...")
            }
            
            logger.info("✅ Synced \(totalAlbums) total albums")
            
            try Task.checkCancellation()
            await reportProgress(.genres)
            try await syncGenres()
            logger.info("✅ Synced genres")
            
            try Task.checkCancellation()
            await downloadAllCovers(totalAlbums: totalAlbums)
            
            await reportProgress(.complete)
        }
        
        do {
            try await syncTask?.value
            logger.info("✅ FULL offline sync complete")
            
            hasCompletedFullSync = true
            UserDefaults.standard.set(true, forKey: "loop.sync.completed")
            
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
    
    // ✅ FIX: Changed from 'private nonisolated' to '@MainActor private'
        @MainActor
        private func syncAlbumPage(type: String, offset: Int, size: Int) async throws -> Int {
            let params = ["type": type, "offset": String(offset), "size": String(size)]
            
            let albums = try await Task {
                let response: SubsonicResponse = try await client.fetch("getAlbumList2", params: params)
                return response.subsonicResponse.albumList2?.album
            }.value
            
            guard let albums else { return 0 }
            try await repo.saveAlbums(albums)
            return albums.count
        }
        
        // ✅ FIX: Changed from 'private nonisolated' to '@MainActor private'
        @MainActor
        private func syncGenres() async throws {
            let genres = try await Task {
                let response: SubsonicGenresResponse = try await client.fetch("getGenres")
                return response.subsonicResponse.genres?.genre
            }.value
            
            guard let genres else { return }
            try await repo.saveGenres(genres)
        }
        
        // ✅ FIX: Changed from 'nonisolated' to '@MainActor'
        @MainActor
        func syncAlbumDetails(albumId: String) async throws {
            let (details, remoteSongs) = try await Task {
                let response: SubsonicGetAlbumResponse = try await client.fetch("getAlbum", params: ["id": albumId])
                return (response.subsonicResponse.album, response.subsonicResponse.album?.song)
            }.value
            
            guard let details, let remoteSongs else { throw SyncError.invalidResponse }
            try await repo.saveAlbumDetails(album: details, songs: remoteSongs)
            
            if let coverId = details.coverArt {
                Task { await cache.downloadCover(id: coverId) }
            }
        }
    
    private func downloadAllCovers(totalAlbums: Int) async {
        do {
            var allAlbums: [AlbumDTO] = []
            var offset = 0
            let pageSize = 500
            var hasMore = true
            while hasMore {
                let batch = try await repo.getAlbums(offset: offset, limit: pageSize)
                allAlbums.append(contentsOf: batch)
                if batch.count < pageSize { hasMore = false } else { offset += pageSize }
            }
            let albumsWithCovers = allAlbums.filter { $0.coverArtId != nil }
            await withTaskGroup(of: Void.self) { group in
                var downloaded = 0
                let maxConcurrent = 10
                var activeCount = 0
                for album in albumsWithCovers {
                    guard let coverId = album.coverArtId else { continue }
                    if activeCount >= maxConcurrent {
                        await group.next()
                        activeCount -= 1
                        downloaded += 1
                        if downloaded % 10 == 0 {
                            await reportProgress(.covers(current: downloaded, total: albumsWithCovers.count))
                        }
                    }
                    group.addTask { await self.cache.downloadCover(id: coverId, size: 300) }
                    activeCount += 1
                }
            }
        } catch {
            logger.error("Cover download failed: \(error)")
        }
    }
    
    private func reportProgress(_ phase: SyncProgress.Phase) async {
        let progress = SyncProgress(phase: phase)
        if let callback = progressCallback { await callback(progress) }
    }
}

//
//  LibraryViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import SwiftData
import Observation
import OSLog

@Observable @MainActor
final class LibraryViewModel {
    
    // MARK: - State
    var albums: [Album] = []
    var isLoading: Bool = false
    
    // ✅ NEW: Localized status message for UI feedback
    var statusMessage: String?
    
    // Pagination State
    private var currentOffset = 0
    private let limit = 100
    private var canLoadMore = true
    
    // Dependencies
    private let repo: MusicRepository
    private let logger = Logger(subsystem: "com.loopapp", category: "LibraryViewModel")
    
    init(repo: MusicRepository) {
        self.repo = repo
    }
    
    // MARK: - Actions
    
    func loadInitialData() async {
        isLoading = true
        statusMessage = nil
        
        // Reset pagination
        currentOffset = 0
        canLoadMore = true
        
        do {
            let localAlbums = try await repo.getAlbums(limit: limit, offset: 0)
            
            if !localAlbums.isEmpty {
                self.albums = localAlbums
                if localAlbums.count < limit { canLoadMore = false }
                logger.info("✅ Loaded \(localAlbums.count) albums from cache.")
            } else {
                logger.info("⚠️ Database empty. Triggering auto-sync...")
                // ✅ Localized status
                statusMessage = String(localized: "Syncing Library...", comment: "Status message during initial sync")
                await performSync()
            }
        } catch {
            logger.error("❌ Error loading library: \(error)")
            statusMessage = String(localized: "Failed to load library.", comment: "Error message when loading fails")
        }
        
        isLoading = false
    }
    
    func performSync() async {
        isLoading = true
        do {
            try await repo.syncAlbums()
            
            // Reload fresh data
            self.albums = try await repo.getAlbums(limit: limit, offset: 0)
            currentOffset = 0
            canLoadMore = (self.albums.count >= limit)
            
            logger.info("✅ Sync complete. Displaying \(self.albums.count) albums.")
            statusMessage = nil // Clear status on success
            
        } catch {
            logger.error("❌ Sync failed: \(error)")
            statusMessage = String(localized: "Sync failed. Please check connection.", comment: "Error message when sync fails")
        }
        isLoading = false
    }
    
    func loadMore() async {
        guard canLoadMore, !isLoading else { return }
        
        isLoading = true
        currentOffset += limit
        
        do {
            let nextBatch = try await repo.getAlbums(limit: limit, offset: currentOffset)
            
            if nextBatch.isEmpty {
                canLoadMore = false
            } else {
                self.albums.append(contentsOf: nextBatch)
                if nextBatch.count < limit { canLoadMore = false }
            }
        } catch {
            logger.error("❌ Pagination Error: \(error)")
        }
        
        isLoading = false
    }
}

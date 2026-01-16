//
//  LibraryViewModel.swift
//  Loop
//
//  Fixed: Removed unnecessary awaits & added status property
//

import Foundation
import Observation

@Observable @MainActor
final class LibraryViewModel {
    
    enum LibraryScope {
        case recent
        case artists
        case genres
    }
    
    var scope: LibraryScope = .recent
    
    var recentAlbums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
    var genres: [Loop.Genre] = []
    
    var isLoading = false
    var statusMessage: String? // ✅ Added
    
    private let repo: MusicRepository
    private let syncManager: SyncManager
    
    init(repo: MusicRepository, syncManager: SyncManager) {
        self.repo = repo
        self.syncManager = syncManager
    }
    
    func loadInitialData() async {
        isLoading = true
        fetchLocalData()
        
        // Auto-sync if empty
        if recentAlbums.isEmpty {
            await refresh()
        }
        isLoading = false
    }
    
    func refresh() async {
        statusMessage = "Syncing..."
        do {
            try await syncManager.performSmartSync()
            fetchLocalData()
            statusMessage = "Up to date"
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            statusMessage = nil
            
        } catch {
            statusMessage = "Sync failed"
        }
    }
    
    private func fetchLocalData() {
        // ✅ FIX: Removed 'await' from these calls
        do {
            self.recentAlbums = try repo.getAlbums(limit: 50)
            self.artists = try repo.getArtists(limit: 100)
            self.genres = try repo.getGenres()
        } catch {
            print("Error fetching local data: \(error)")
        }
    }
}

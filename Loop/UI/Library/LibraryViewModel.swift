//
//  LibraryViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation
import OSLog

@Observable @MainActor
final class LibraryViewModel {
    
    // MARK: - Enums
    enum LibraryScope: String, CaseIterable, Identifiable {
        case albums = "Albums"
        case artists = "Artists"
        var id: Self { self }
    }
    
    // MARK: - State
    var selectedScope: LibraryScope = .albums
    
    var albums: [Album] = []
    var artists: [Artist] = [] // ✅ Added
    
    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?
    
    // Local Filter
    var searchText: String = ""
    
    // ✅ Computed property to switch data source based on Scope
    var filteredItems: [any Identifiable] {
        switch selectedScope {
        case .albums:
            guard !searchText.isEmpty else { return albums }
            return albums.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        case .artists:
            guard !searchText.isEmpty else { return artists }
            return artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - Dependencies
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let logger = Logger(subsystem: "com.loopapp", category: "Library")
    
    init(repo: MusicRepository, downloads: DownloadManager) {
        self.repo = repo
        self.downloads = downloads
    }
    
    // MARK: - Actions
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        statusMessage = "Loading library..."
        
        do {
            // 1. Load Local Cache
            async let fetchedAlbums = repo.getAlbums(limit: 500) // Increased limit for library view
            async let fetchedArtists = repo.getArtists()
            
            let (newAlbums, newArtists) = try await (fetchedAlbums, fetchedArtists)
            
            self.albums = newAlbums
            self.artists = newArtists
            
            // 2. Trigger Background Sync
            performSync()
            
        } catch {
            logger.error("Failed to load library: \(error)")
            errorMessage = "Failed to load library."
        }
        
        isLoading = false
        statusMessage = nil
    }
    
    func performSync() {
        Task {
            statusMessage = "Syncing..."
            do {
                try await repo.syncAlbums()
                
                // Refresh Data
                self.albums = try await repo.getAlbums(limit: 500)
                self.artists = try await repo.getArtists()
                
            } catch {
                logger.error("Sync failed: \(error)")
            }
            statusMessage = nil
        }
    }
}

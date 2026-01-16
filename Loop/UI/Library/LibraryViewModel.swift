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
    
    enum LibraryScope: String, CaseIterable, Identifiable {
        case albums = "Albums"
        case artists = "Artists"
        case genres = "Genres"
        var id: Self { self }
    }
    
    // MARK: - State
    var selectedScope: LibraryScope = .albums
    var showDownloadedOnly: Bool = false
    var isSyncing: Bool = false
    
    // Data Sources
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
    var genres: [Loop.Genre] = []
    
    // Search State
    var searchText: String = "" {
        didSet {
            // Debounce could be added here, but for local DB, direct call is usually fine
            performSearch()
        }
    }
    
    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?
    
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let logger = Logger(subsystem: "com.loopapp", category: "Library")
    
    init(repo: MusicRepository, downloads: DownloadManager) {
        self.repo = repo
        self.downloads = downloads
    }
    
    // MARK: - Computed Data
    // We strictly separate "Browsing Mode" vs "Search Mode"
    
    var filteredAlbums: [Loop.Album] {
        if showDownloadedOnly {
            return albums.filter { album in album.songs.contains { downloads.isPinned(songId: $0.id) } }
        }
        return albums
    }
    
    var filteredArtists: [Loop.Artist] {
        // Simple logic: If searching, 'artists' already contains search results.
        return artists
    }
    
    var filteredGenres: [Loop.Genre] {
        return genres
    }
    
    var isCurrentViewEmpty: Bool {
        switch selectedScope {
        case .albums: return filteredAlbums.isEmpty
        case .artists: return filteredArtists.isEmpty
        case .genres: return filteredGenres.isEmpty
        }
    }

    // MARK: - Actions
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        await refreshLocalData()
        performSmartSync()
    }
    
    func performSmartSync() {
        Task {
            await repo.syncSmart { [weak self] syncing in
                self?.isSyncing = syncing
                if !syncing { Task { await self?.refreshLocalData() } }
            }
        }
    }
    
    func refreshLocalData() async {
        guard searchText.isEmpty else { return } // Don't overwrite search results
        
        do {
            // Default Browse Mode: Fetch latest 5000 items
            let fetchedAlbums = try await repo.getAlbums(limit: 5000)
            let fetchedArtists = try await repo.getArtists()
            let fetchedGenres = try await repo.getGenres()
            
            self.albums = fetchedAlbums
            self.artists = fetchedArtists
            self.genres = fetchedGenres
            self.isLoading = false
        } catch {
            logger.error("Refresh failed: \(error)")
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            Task { await refreshLocalData() }
            return
        }
        
        // SQL Search Mode: Query the entire DB
        let results = repo.searchLocal(query: searchText)
        
        // Update the views with search results
        self.albums = results.albums
        self.artists = results.artists
        // (Optional: You could search genres too if you updated repo.searchLocal to return them)
    }
}

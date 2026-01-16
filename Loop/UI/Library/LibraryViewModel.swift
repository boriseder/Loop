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
    
    // Sync State
    var isSyncing: Bool = false
    
    // Data
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
    var genres: [Loop.Genre] = []
    
    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?
    
    var searchText: String = ""
    
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let logger = Logger(subsystem: "com.loopapp", category: "Library")
    
    init(repo: MusicRepository, downloads: DownloadManager) {
        self.repo = repo
        self.downloads = downloads
    }
    
    // MARK: - Filter Logic
    var filteredAlbums: [Loop.Album] {
        var result = albums
        if showDownloadedOnly {
            result = result.filter { album in album.songs.contains { downloads.isPinned(songId: $0.id) } }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var filteredArtists: [Loop.Artist] {
        var result = artists
        if showDownloadedOnly {
            result = result.filter { artist in artist.songs.contains { downloads.isPinned(songId: $0.id) } }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var filteredGenres: [Loop.Genre] {
        var result = genres
        if showDownloadedOnly {
            let downloadedGenres = Set(albums.filter { album in album.songs.contains { downloads.isPinned(songId: $0.id) } }.compactMap { $0.genre })
            result = result.filter { downloadedGenres.contains($0.name) }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
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
        
        // 1. Load what we have locally immediately
        await refreshLocalData()
        isLoading = false
        
        // 2. Trigger Smart Sync (Prioritized)
        performSmartSync()
    }
    
    func performSmartSync() {
        Task {
            await repo.syncSmart { [weak self] syncing in
                self?.isSyncing = syncing
                // Whenever sync state updates, likely data updated too, so refresh local view
                Task { await self?.refreshLocalData() }
            }
        }
    }
    
    func refreshLocalData() async {
        do {
            // We fetch a decent amount to fill the UI.
            // In a real optimized app, this would be paginated or use @Query in the View.
            let fetchedAlbums = try await repo.getAlbums(limit: 5000)
            let fetchedArtists = try await repo.getArtists()
            let fetchedGenres = try await repo.getGenres()
            
            self.albums = fetchedAlbums
            self.artists = fetchedArtists
            self.genres = fetchedGenres
        } catch {
            logger.error("Refresh failed: \(error)")
        }
    }
}

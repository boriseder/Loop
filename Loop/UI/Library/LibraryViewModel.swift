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
        case genres = "Genres"
        var id: Self { self }
    }
    
    // MARK: - State
    var selectedScope: LibraryScope = .albums
    
    // Raw Data
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
    var genres: [Loop.Genre] = []
    
    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?
    
    var searchText: String = ""
    
    // MARK: - Safe Typed Filtered Lists (Removes View Casting Issues)
    
    var filteredAlbums: [Loop.Album] {
        if searchText.isEmpty { return albums }
        return albums.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredArtists: [Loop.Artist] {
        if searchText.isEmpty { return artists }
        return artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredGenres: [Loop.Genre] {
        if searchText.isEmpty { return genres }
        return genres.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Helper to check if current view is empty
    var isCurrentViewEmpty: Bool {
        switch selectedScope {
        case .albums: return filteredAlbums.isEmpty
        case .artists: return filteredArtists.isEmpty
        case .genres: return filteredGenres.isEmpty
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
            // 1. Fetch Local Data
            async let fetchedAlbums = repo.getAlbums(limit: 500)
            async let fetchedArtists = repo.getArtists()
            async let fetchedGenres = repo.getGenres()
            
            let (newAlbums, newArtists, newGenres) = try await (fetchedAlbums, fetchedArtists, fetchedGenres)
            
            self.albums = newAlbums
            self.artists = newArtists
            self.genres = newGenres
            
            print("📊 VM Loaded: \(albums.count) albums, \(artists.count) artists, \(genres.count) genres")
            
            // 2. Trigger Sync
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
                try await repo.syncAlbums() // Syncs everything
                
                // Refresh all data
                self.albums = try await repo.getAlbums(limit: 500)
                self.artists = try await repo.getArtists()
                self.genres = try await repo.getGenres()
                
                print("🔄 VM Refreshed: \(genres.count) genres available.")
                
            } catch {
                logger.error("Sync failed: \(error)")
            }
            statusMessage = nil
        }
    }
}

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
    var showDownloadedOnly: Bool = false // ✅ RESTORED
    
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
    var genres: [Loop.Genre] = []
    
    var isLoading = false
    var errorMessage: String?
    var statusMessage: String?
    
    var searchText: String = ""
    
    // MARK: - Dependencies
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let logger = Logger(subsystem: "com.loopapp", category: "Library")
    
    init(repo: MusicRepository, downloads: DownloadManager) {
        self.repo = repo
        self.downloads = downloads
    }
    
    // MARK: - Filter Logic (RESTORED)
    
    var filteredAlbums: [Loop.Album] {
        var result = albums
        
        if showDownloadedOnly {
            result = result.filter { album in
                // Keep album if ANY song is downloaded
                album.songs.contains { downloads.isPinned(songId: $0.id) }
            }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var filteredArtists: [Loop.Artist] {
        var result = artists
        
        if showDownloadedOnly {
            result = result.filter { artist in
                artist.songs.contains { downloads.isPinned(songId: $0.id) }
            }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var filteredGenres: [Loop.Genre] {
        var result = genres
        
        if showDownloadedOnly {
            // Find genres associated with downloaded albums
            let downloadedGenres = Set(albums.filter { album in
                album.songs.contains { downloads.isPinned(songId: $0.id) }
            }.compactMap { $0.genre })
            
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
        statusMessage = "Loading library..."
        
        do {
            async let fetchedAlbums = repo.getAlbums(limit: 500)
            async let fetchedArtists = repo.getArtists()
            async let fetchedGenres = repo.getGenres()
            
            let (newAlbums, newArtists, newGenres) = try await (fetchedAlbums, fetchedArtists, fetchedGenres)
            
            self.albums = newAlbums
            self.artists = newArtists
            self.genres = newGenres
            
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
                self.albums = try await repo.getAlbums(limit: 500)
                self.artists = try await repo.getArtists()
                self.genres = try await repo.getGenres()
            } catch {
                logger.error("Sync failed: \(error)")
            }
            statusMessage = nil
        }
    }
}

//
//  LibraryViewModel.swift
//  Loop
//
//  FIXED: Uses async MusicEnvironment, proper pagination support
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
    
    var scope: LibraryScope = .recent {
        didSet {
            if scope != oldValue {
                resetPagination()
                Task { await loadCurrentScope() }
            }
        }
    }
    
    var recentAlbums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
    var genres: [GenreDTO] = []
    
    var isLoading = false
    var statusMessage: String?
    var canLoadMore = true
    
    private var currentOffset = 0
    private let pageSize = 100  // Load 100 at a time
    
    private let music: MusicEnvironment
    
    init(music: MusicEnvironment) {
        self.music = music
    }
    
    func loadInitialData() async {
        isLoading = true
        await loadCurrentScope()
        
        // For offline-first: Auto-sync on first launch if empty
        if recentAlbums.isEmpty && artists.isEmpty && genres.isEmpty {
            statusMessage = "First launch - downloading library..."
            await refresh()
        }
        isLoading = false
    }
    
    func refresh() async {
        statusMessage = "Syncing library and covers..."
        do {
            try await music.performSync()
            resetPagination()
            await loadCurrentScope()
            
            statusMessage = "✅ Offline library ready"
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMessage = nil
            
        } catch {
            statusMessage = "Sync failed: \(error.localizedDescription)"
        }
    }
    
    func loadMore() async {
        guard canLoadMore && !isLoading else { return }
        
        currentOffset += pageSize
        await loadCurrentScope(append: true)
    }
    
    private func loadCurrentScope(append: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            switch scope {
            case .recent:
                let newAlbums = try await music.getAlbums(offset: currentOffset, limit: pageSize)
                if append {
                    recentAlbums.append(contentsOf: newAlbums)
                } else {
                    recentAlbums = newAlbums
                }
                canLoadMore = newAlbums.count == pageSize
                print("📚 Loaded \(newAlbums.count) albums, total: \(recentAlbums.count)")
                
            case .artists:
                let newArtists = try await music.getArtists(offset: currentOffset, limit: pageSize)
                if append {
                    artists.append(contentsOf: newArtists)
                } else {
                    artists = newArtists
                }
                canLoadMore = newArtists.count == pageSize
                print("🎤 Loaded \(newArtists.count) artists, total: \(artists.count)")
                
            case .genres:
                if !append { // Genres loaded all at once
                    genres = try await music.getGenres()
                    print("🎵 Loaded \(genres.count) genres")
                }
                canLoadMore = false
            }
        } catch {
            print("❌ Error loading: \(error)")
            statusMessage = "Failed to load: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func resetPagination() {
        currentOffset = 0
        canLoadMore = true
    }
}

//
//  LibraryViewModel.swift
//  Loop
//
//  FIXED: Renamed 'recentAlbums' -> 'albums', uses Global Download State
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
    
    // ✅ RENAMED: 'recentAlbums' is misleading. It's just 'albums'.
    var albums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
    var genres: [GenreDTO] = []
    
    // ✅ FILTERED: Uses Global State from 'music' environment directly
    // This ensures that if the state updates anywhere in the app, this view updates instantly.
    var filteredAlbums: [AlbumDTO] {
        showDownloadedOnly ? albums.filter { music.downloadedAlbumIds.contains($0.id) } : albums
    }
    
    var filteredArtists: [ArtistDTO] {
        showDownloadedOnly ? artists.filter { music.downloadedArtistIds.contains($0.id) } : artists
    }
    
    var filteredGenres: [GenreDTO] {
        showDownloadedOnly ? genres.filter { music.downloadedGenres.contains($0.name) } : genres
    }
    
    var isLoading = false
    var statusMessage: String?
    var canLoadMore = true
    var showDownloadedOnly = false
    
    private var currentOffset = 0
    private let pageSize = 100
    
    private let music: MusicEnvironment
    private let downloads: DownloadEnvironment
    
    init(music: MusicEnvironment, downloads: DownloadEnvironment) {
        self.music = music
        self.downloads = downloads
    }
    
    func loadInitialData() async {
        // 1. Try to load existing data from DB
        await loadCurrentScope()
        
        // 2. Refresh Global Download State (scans the disk)
        await music.updateDownloadedState()
        
        // 3. Only force sync if DB is TRULY empty
        if albums.isEmpty && artists.isEmpty && genres.isEmpty {
            print("⚠️ DB is empty. Triggering Force Sync.")
            statusMessage = "First launch - downloading library..."
            await refresh(force: true)
        } else {
            print("✅ Loaded \(albums.count) albums from local DB")
        }
    }
    
    func updateFilter(downloadedOnly: Bool) async {
        showDownloadedOnly = downloadedOnly
        if downloadedOnly {
            // Trigger a fresh scan when filter is enabled to be sure
            await music.updateDownloadedState()
        }
    }
    
    func refresh(force: Bool = false) async {
        statusMessage = "Syncing..."
        do {
            try await music.performSync(force: force)
            
            // 3. Reload data after sync
            resetPagination()
            await loadCurrentScope()
            // Update global state after sync potentially brought in new files/metadata
            await music.updateDownloadedState()
            
            statusMessage = "✅ Ready"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
                    albums.append(contentsOf: newAlbums)
                } else {
                    albums = newAlbums
                }
                canLoadMore = newAlbums.count == pageSize
                
            case .artists:
                let newArtists = try await music.getArtists(offset: currentOffset, limit: pageSize)
                if append {
                    artists.append(contentsOf: newArtists)
                } else {
                    artists = newArtists
                }
                canLoadMore = newArtists.count == pageSize
                
            case .genres:
                if !append {
                    genres = try await music.getGenres()
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

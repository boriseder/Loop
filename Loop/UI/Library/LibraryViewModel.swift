//
//  LibraryViewModel.swift
//  Loop
//
//  FIXED: Robust state handling (defer) and pagination reset on reload
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
                // Cancel previous tasks implicitly by starting new one
                Task { await loadCurrentScope() }
            }
        }
    }
    
    var albums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
    var genres: [GenreDTO] = []
    
    var filteredAlbums: [AlbumDTO] {
        showDownloadedOnly ? albums.filter { music.downloadedAlbumIds.contains($0.id) } : albums
    }
    
    var filteredArtists: [ArtistDTO] {
        showDownloadedOnly ? artists.filter { music.downloadedArtistIds.contains($0.id) } : artists
    }
    
    var isInitialLoad = true

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
        resetPagination()
        
        await loadCurrentScope()
        await music.updateDownloadedState()
        
        if albums.isEmpty && artists.isEmpty && genres.isEmpty {
            statusMessage = "First launch - downloading library..."
            await refresh(force: true)
        } else {
            print("✅ Loaded \(albums.count) albums from local DB")
        }
        
        // Mark initial load as complete
        isInitialLoad = false
    }

    func updateFilter(downloadedOnly: Bool) async {
        showDownloadedOnly = downloadedOnly
        if downloadedOnly {
            await music.updateDownloadedState()
        }
    }
    
    func refresh(force: Bool = false) async {
        statusMessage = "Syncing..."
        do {
            try await music.performSync(force: force)
            
            resetPagination()
            await loadCurrentScope()
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
        
        // ✅ FIX: Ensure isLoading is ALWAYS reset, even if cancelled/crashed
        defer { isLoading = false }
        
        do {
            switch scope {
            case .recent:
                // Use the safe Repo method (Sorting in memory)
                let newAlbums = try await music.getAlbums(offset: currentOffset, limit: pageSize)
                
                if append {
                    albums.append(contentsOf: newAlbums)
                } else {
                    albums = newAlbums
                }
                canLoadMore = newAlbums.count == pageSize
                
            case .artists:
                let newArtists = try await music.getArtists(offset: currentOffset, limit: pageSize)
                print("✅ ViewModel: Received \(newArtists.count) artists")
                
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
    }
    
    private func resetPagination() {
        currentOffset = 0
        canLoadMore = true
    }
}

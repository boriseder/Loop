//
//  LibraryViewModel.swift
//  Loop
//
//  With pagination, debouncing, and proper error handling
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
    var selectedScope: LibraryScope = .albums {
        didSet {
            if oldValue != selectedScope {
                resetPagination()
                Task { await loadInitialData() }
            }
        }
    }
    
    var showDownloadedOnly: Bool = false {
        didSet {
            filterData()
        }
    }
    
    var isSyncing: Bool = false
    
    // Data Sources
    private var allAlbums: [Loop.Album] = []
    private var allArtists: [Loop.Artist] = []
    private var allGenres: [Loop.Genre] = []
    
    var filteredAlbums: [Loop.Album] = []
    var filteredArtists: [Loop.Artist] = []
    var filteredGenres: [Loop.Genre] = []
    
    // Pagination
    private var currentOffset = 0
    private let pageSize = 100
    private var canLoadMore = true
    
    // Search State
    var searchText: String = "" {
        didSet {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                await performSearch()
            }
        }
    }
    private var searchTask: Task<Void, Never>?
    
    var isLoading = false
    var errorMessage: String?
    
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let syncManager: SyncManager
    private let logger = Logger(subsystem: "com.loopapp", category: "Library")
    
    init(repo: MusicRepository, downloads: DownloadManager, syncManager: SyncManager) {
        self.repo = repo
        self.downloads = downloads
        self.syncManager = syncManager
    }
    
    // MARK: - Computed Properties
    
    var isCurrentViewEmpty: Bool {
        switch selectedScope {
        case .albums: return filteredAlbums.isEmpty
        case .artists: return filteredArtists.isEmpty
        case .genres: return filteredGenres.isEmpty
        }
    }

    // MARK: - Actions
    
    func loadInitialData() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if searchText.isEmpty {
                try await loadPage()
            } else {
                await performSearch()
            }
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Load failed: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMore() async {
        guard canLoadMore, !isLoading, searchText.isEmpty else { return }
        
        do {
            try await loadPage()
        } catch {
            logger.error("Load more failed: \(error)")
        }
    }
    
    func performSmartSync() {
        Task {
            isSyncing = true
            
            do {
                try await syncManager.performSmartSync()
                
                // Reload data after sync
                resetPagination()
                await loadInitialData()
                
            } catch {
                errorMessage = error.localizedDescription
                logger.error("Sync failed: \(error)")
            }
            
            isSyncing = false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPage() async throws {
        switch selectedScope {
        case .albums:
            let newAlbums = try await repo.getAlbums(offset: currentOffset, limit: pageSize)
            if newAlbums.count < pageSize {
                canLoadMore = false
            }
            allAlbums.append(contentsOf: newAlbums)
            currentOffset += newAlbums.count
            
        case .artists:
            let newArtists = try await repo.getArtists(offset: currentOffset, limit: pageSize)
            if newArtists.count < pageSize {
                canLoadMore = false
            }
            allArtists.append(contentsOf: newArtists)
            currentOffset += newArtists.count
            
        case .genres:
            // Genres are typically small, load all at once
            allGenres = try await repo.getGenres()
            canLoadMore = false
        }
        
        filterData()
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else {
            resetPagination()
            await loadInitialData()
            return
        }
        
        let results = repo.search(query: searchText)
        
        allAlbums = results.albums
        allArtists = results.artists
        allGenres = [] // Could add genre search if needed
        
        filterData()
    }
    
    private func filterData() {
        if showDownloadedOnly {
            filteredAlbums = allAlbums.filter { album in
                album.songs.contains { downloads.isPinned(songId: $0.id) }
            }
            filteredArtists = allArtists.filter { artist in
                artist.albums.contains { album in
                    album.songs.contains { downloads.isPinned(songId: $0.id) }
                }
            }
            filteredGenres = allGenres // Could filter if needed
        } else {
            filteredAlbums = allAlbums
            filteredArtists = allArtists
            filteredGenres = allGenres
        }
    }
    
    private func resetPagination() {
        currentOffset = 0
        canLoadMore = true
        allAlbums = []
        allArtists = []
        allGenres = []
        filteredAlbums = []
        filteredArtists = []
        filteredGenres = []
    }
}

//
//  LibraryViewModel.swift
//  Loop
//
//  FIXED: Albums sorted alphabetically A-Z
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
    
    // ✅ NEW: Filtered results for downloaded-only mode
    var filteredAlbums: [AlbumDTO] { showDownloadedOnly ? recentAlbums.filter { isAlbumDownloaded($0) } : recentAlbums }
    var filteredArtists: [ArtistDTO] { showDownloadedOnly ? artists.filter { hasDownloadedAlbums(artistId: $0.id) } : artists }
    var filteredGenres: [GenreDTO] { showDownloadedOnly ? genres.filter { hasDownloadedAlbums(genre: $0.name) } : genres }
    
    var isLoading = false
    var statusMessage: String?
    var canLoadMore = true
    var showDownloadedOnly = false
    
    private var currentOffset = 0
    private let pageSize = 100
    
    private let music: MusicEnvironment
    private let downloads: DownloadEnvironment
    
    // ✅ Cache of downloaded albums
    private var downloadedAlbumIds: Set<String> = []
    
    init(music: MusicEnvironment, downloads: DownloadEnvironment) {
        self.music = music
        self.downloads = downloads
    }
    
    func loadInitialData() async {
        isLoading = true
        await loadCurrentScope()
        await updateDownloadedAlbums()
        
        // ✅ FIXED: Only auto-sync on first launch if empty
        if recentAlbums.isEmpty && artists.isEmpty && genres.isEmpty {
            statusMessage = "First launch - downloading library..."
            await refresh()
        }
        
        isLoading = false
    }
    
    func updateFilter(downloadedOnly: Bool) async {
        showDownloadedOnly = downloadedOnly
        await updateDownloadedAlbums()
    }
    
    private func updateDownloadedAlbums() async {
        // Build cache of downloaded album IDs
        var downloaded = Set<String>()
        
        for album in recentAlbums {
            do {
                let songs = try await music.getSongs(for: album.id)
                if downloads.isAlbumFullyDownloaded(songIds: songs.map(\.id)) {
                    downloaded.insert(album.id)
                }
            } catch {
                continue
            }
        }
        
        downloadedAlbumIds = downloaded
    }
    
    private func isAlbumDownloaded(_ album: AlbumDTO) -> Bool {
        downloadedAlbumIds.contains(album.id)
    }
    
    private func hasDownloadedAlbums(artistId: String) -> Bool {
        recentAlbums.contains { $0.artistId == artistId && downloadedAlbumIds.contains($0.id) }
    }
    
    private func hasDownloadedAlbums(genre: String) -> Bool {
        recentAlbums.contains { $0.genre == genre && downloadedAlbumIds.contains($0.id) }
    }
    
    func refresh() async {
        statusMessage = "Syncing library and covers..."
        do {
            try await music.performSync()
            resetPagination()
            await loadCurrentScope()
            await updateDownloadedAlbums()
            
            statusMessage = "✅ Offline library ready"
            
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
                // ✅ FIXED: Sort alphabetically by title
                let sortedAlbums = newAlbums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                
                if append {
                    recentAlbums.append(contentsOf: sortedAlbums)
                } else {
                    recentAlbums = sortedAlbums
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
                if !append {
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

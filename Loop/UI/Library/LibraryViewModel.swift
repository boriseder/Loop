//
//  LibraryViewModel.swift
//  Loop
//
//  FIXED: Removed 'isLoading' deadlock that prevented data from rendering
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
    
    private var downloadedAlbumIds: Set<String> = []
    
    init(music: MusicEnvironment, downloads: DownloadEnvironment) {
        self.music = music
        self.downloads = downloads
    }
    
    func loadInitialData() async {
        // ❌ REMOVED: isLoading = true
        // (This was causing the deadlock because loadCurrentScope checks this flag and aborts)
        
        // 1. Try to load existing data from DB
        await loadCurrentScope()
        await updateDownloadedAlbums()
        
        // 2. Only force sync if DB is TRULY empty
        if recentAlbums.isEmpty && artists.isEmpty && genres.isEmpty {
            print("⚠️ DB is empty. Triggering Force Sync.")
            statusMessage = "First launch - downloading library..."
            await refresh(force: true)
        } else {
            print("✅ Loaded \(recentAlbums.count) albums from local DB")
        }
    }
    
    func updateFilter(downloadedOnly: Bool) async {
        showDownloadedOnly = downloadedOnly
        await updateDownloadedAlbums()
    }
    
    private func updateDownloadedAlbums() async {
        let currentScopeAlbums = recentAlbums
        let storage = downloads.storage
        
        let newDownloadedIds = await Task.detached(priority: .userInitiated) { [music, storage, currentScopeAlbums] in
            var ids = Set<String>()
            
            await withTaskGroup(of: (String, Bool).self) { group in
                for album in currentScopeAlbums {
                    group.addTask {
                        guard let songs = try? await music.getSongs(for: album.id) else { return (album.id, false) }
                        let isDown = storage.isAlbumFullyDownloaded(songIds: songs.map(\.id))
                        return (album.id, isDown)
                    }
                }
                
                for await (id, isDown) in group {
                    if isDown { ids.insert(id) }
                }
            }
            return ids
        }.value
        
        self.downloadedAlbumIds = newDownloadedIds
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
    
    func refresh(force: Bool = false) async {
        statusMessage = "Syncing..."
        do {
            try await music.performSync(force: force)
            
            // 3. Reload data after sync
            resetPagination()
            await loadCurrentScope() // This will now work because isLoading is managed correctly
            await updateDownloadedAlbums()
            
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
                // Direct DB read (Fast)
                let newAlbums = try await music.getAlbums(offset: currentOffset, limit: pageSize)
                
                if append {
                    recentAlbums.append(contentsOf: newAlbums)
                } else {
                    recentAlbums = newAlbums
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

//
//  SearchViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation
import OSLog

@Observable @MainActor
final class SearchViewModel {
    
    // MARK: - State
    var searchText: String = "" {
        didSet {
            // Cancel previous task to debounce
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                if !Task.isCancelled {
                    await performSearch()
                }
            }
        }
    }
    
    // Domain Models
    var albums: [Loop.Album] = []
    var artists: [Loop.Artist] = []
    var songs: [Loop.Song] = []
    
    var isLoading = false
    var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Dependencies
    private let client: NavidromeClient
    private let repo: MusicRepository
    private let logger = Logger(subsystem: "com.loopapp", category: "Search")
    
    init(client: NavidromeClient, repo: MusicRepository) {
        self.client = client
        self.repo = repo
    }
    
    // MARK: - Actions
    
    func performSearch() async {
        guard !searchText.isEmpty else {
            clearResults()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ FIX: Destructure the tuple (Songs, Albums, Artists)
            let (remoteSongs, remoteAlbums, remoteArtists) = try await client.search(query: searchText)
            
            // Map Remote DTOs to Domain Models manually
            
            // 1. Map Albums
            self.albums = remoteAlbums.map { remote in
                Loop.Album(
                    id: remote.id,
                    title: remote.name,
                    artistId: remote.artistId,
                    coverArtId: remote.coverArt,
                    year: remote.year,
                    genre: remote.genre
                )
            }
            
            // 2. Map Artists
            self.artists = remoteArtists.map { remote in
                Loop.Artist(
                    id: remote.id,
                    name: remote.name
                )
            }
            
            // 3. Map Songs
            self.songs = remoteSongs.map { remote in
                Loop.Song(
                    id: remote.id,
                    title: remote.title,
                    trackNumber: remote.track ?? 0,
                    duration: TimeInterval(remote.duration ?? 0),
                    path: remote.path ?? "",
                    artistId: "unknown", // Search result usually lacks strict Artist ID, relies on name
                    albumId: remote.albumId ?? "unknown"
                )
            }
            
        } catch {
            logger.error("Search failed: \(error)")
            if !searchText.isEmpty {
                errorMessage = "Could not search server."
            }
        }
        
        isLoading = false
    }
    
    private func clearResults() {
        albums = []
        artists = []
        songs = []
        isLoading = false
        errorMessage = nil
    }
}

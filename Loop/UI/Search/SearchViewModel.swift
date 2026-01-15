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
    
    // MARK: - Enums
    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        
        var id: Self { self }
        
        var localizedName: String {
            NSLocalizedString(self.rawValue, comment: "Search scope")
        }
    }
    
    // MARK: - State
    var query: String = "" {
        didSet {
            // Debounce logic could go here, for now we rely on the View's .onSubmit or .onChange
            if query.isEmpty {
                clearResults()
            } else {
                Task { await search() }
            }
        }
    }
    
    var selectedScope: SearchScope = .all
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Results
    // We use the Database models directly so the View can reuse components
    var displayedSongs: [Song] = []
    var displayedAlbums: [Album] = []
    var displayedArtists: [Artist] = []
    
    // MARK: - Dependencies
    private let repo: MusicRepository
    private let logger = Logger(subsystem: "com.loopapp", category: "Search")
    
    init(repo: MusicRepository) {
        self.repo = repo
    }
    
    // MARK: - Actions
    
    func search() async {
        guard !query.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (remoteSongs, remoteAlbums, remoteArtists) = try await repo.search(query: query)
            
            // Map Remote DTOs to Transient Local Models (not saving to DB yet)
            // We create temporary instances just for display
            
            // 1. Map Songs
            self.displayedSongs = remoteSongs.map { remote in
                Song(
                    id: remote.id,
                    title: remote.title,
                    trackNumber: remote.track ?? 0,
                    duration: TimeInterval(remote.duration ?? 0),
                    path: remote.path ?? "",
                    artistId: remote.artist ?? "unknown", // Search result might lack ID, using name as fallback if needed
                    albumId: remote.albumId ?? "unknown"
                )
            }
            
            // 2. Map Albums (✅ FIX: Added coverArtId, year, genre)
            self.displayedAlbums = remoteAlbums.map { remote in
                Album(
                    id: remote.id,
                    title: remote.name,
                    artistId: remote.artistId,
                    coverArtId: remote.coverArt, // Passed correctly
                    year: remote.year,           // Passed correctly
                    genre: remote.genre          // Passed correctly
                )
            }
            
            // 3. Map Artists
            self.displayedArtists = remoteArtists.map { remote in
                Artist(
                    id: remote.id,
                    name: remote.name
                )
            }
            
            // Filter based on Scope
            filterResults()
            
        } catch {
            logger.error("Search failed: \(error)")
            errorMessage = "Search failed. Please try again."
        }
        
        isLoading = false
    }
    
    private func filterResults() {
        switch selectedScope {
        case .all:
            break // Show everything
        case .songs:
            displayedAlbums = []
            displayedArtists = []
        case .albums:
            displayedSongs = []
            displayedArtists = []
        case .artists:
            displayedSongs = []
            displayedAlbums = []
        }
    }
    
    private func clearResults() {
        displayedSongs = []
        displayedAlbums = []
        displayedArtists = []
    }
}

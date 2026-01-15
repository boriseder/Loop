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
    
    // MARK: - Search Scopes
    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        
        var id: Self { self }
        
        // Localized display title
        var localizedName: String {
            switch self {
            case .all: return String(localized: "All", comment: "Search scope all")
            case .songs: return String(localized: "Songs", comment: "Search scope songs")
            case .albums: return String(localized: "Albums", comment: "Search scope albums")
            case .artists: return String(localized: "Artists", comment: "Search scope artists")
            }
        }
    }
    
    // MARK: - State
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    
    var selectedScope: SearchScope = .all
    
    // Raw Results
    var songs: [Song] = []
    var albums: [Album] = []
    var artists: [Artist] = []
    
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Filtered Outputs
    // These helpers ensure the View only sees what the Scope allows
    
    var displayedSongs: [Song] {
        return (selectedScope == .all || selectedScope == .songs) ? songs : []
    }
    
    var displayedAlbums: [Album] {
        return (selectedScope == .all || selectedScope == .albums) ? albums : []
    }
    
    var displayedArtists: [Artist] {
        return (selectedScope == .all || selectedScope == .artists) ? artists : []
    }
    
    // MARK: - Dependencies
    private let repo: MusicRepository
    private var searchTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.loopapp", category: "Search")
    
    init(repo: MusicRepository) {
        self.repo = repo
    }
    
    // MARK: - Actions
    private func scheduleSearch() {
        searchTask?.cancel()
        
        guard query.count > 2 else {
            clearResults()
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            
            await performSearch()
        }
    }
    
    private func performSearch() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (remoteSongs, remoteAlbums, remoteArtists) = try await repo.search(query: query)
            
            // Map to Domain Models
            let mappedSongs = remoteSongs.map { mapSong($0) }
            let mappedAlbums = remoteAlbums.map { mapAlbum($0) }
            let mappedArtists = remoteArtists.map { Artist(id: $0.id, name: $0.name) }
            
            withAnimation {
                self.songs = mappedSongs
                self.albums = mappedAlbums
                self.artists = mappedArtists
            }
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            logger.error("Search failed: \(error)")
            errorMessage = String(localized: "Search failed. Please try again.", comment: "Search error")
        }
        
        isLoading = false
    }
    
    private func clearResults() {
        songs = []
        albums = []
        artists = []
        errorMessage = nil
        isLoading = false
    }
    
    // MARK: - Mappers
    private func mapSong(_ remote: RemoteSong) -> Song {
        let song = Song(
            id: remote.id,
            title: remote.title,
            trackNumber: remote.track ?? 0,
            duration: TimeInterval(remote.duration ?? 0),
            path: "",
            artistId: "search-artist",
            albumId: "search-album"
        )
        if let artistName = remote.artist {
            song.artist = Artist(id: "search-artist-obj", name: artistName)
        }
        if let albumName = remote.album {
            let album = Album(id: "search-album-obj", title: albumName, artistId: "search-artist")
            album.coverArtId = remote.coverArt
            song.album = album
        }
        return song
    }
    
    private func mapAlbum(_ remote: RemoteAlbum) -> Album {
        let album = Album(
            id: remote.id,
            title: remote.name,
            artistId: remote.artistId,
            coverArtId: remote.coverArt,
            year: remote.year
        )
        album.artist = Artist(id: remote.artistId, name: remote.artist)
        return album
    }
}

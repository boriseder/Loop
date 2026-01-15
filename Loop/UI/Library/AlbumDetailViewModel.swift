//
//  AlbumDetailViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation
import OSLog

@Observable @MainActor
final class AlbumDetailViewModel {
    
    // MARK: - State
    var songs: [Song] = []
    var album: Album?
    var isLoading = false
    
    // MARK: - Dependencies
    private let albumId: String
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let logger = Logger(subsystem: "com.loopapp", category: "AlbumDetail")
    
    init(albumId: String, repo: MusicRepository, downloads: DownloadManager) {
        self.albumId = albumId
        self.repo = repo
        self.downloads = downloads
    }
    
    // MARK: - Actions
    
    func load() async {
        isLoading = true
        
        // 1. Sync Details (Get Tracks)
        try? await repo.syncAlbumDetails(albumId: albumId)
        
        // 2. Fetch from DB
        do {
            self.songs = try await repo.getSongs(for: albumId)
            
            // Fetch the Album object itself for the header
            // (We reuse the existing songs list to find the parent if needed, or fetch separately)
            if let firstSong = songs.first {
                self.album = firstSong.album
            }
        } catch {
            logger.error("Failed to load album details: \(error)")
        }
        
        isLoading = false
    }
    
    // ✅ FIX: Download all songs in the album
    func downloadAlbum() {
        guard !songs.isEmpty else { return }
        
        Task {
            for song in songs {
                // We await each one to add them to the queue
                await downloads.download(song: song)
            }
        }
    }
}

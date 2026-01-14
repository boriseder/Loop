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
    var songs: [Song] = []
    var albumTitle: String = ""
    var isLoading: Bool = false
    
    private let repo: MusicRepository
    private let albumId: String
    private let logger = Logger(subsystem: "com.loopapp", category: "AlbumDetailVM")
    
    init(repo: MusicRepository, albumId: String) {
        self.repo = repo
        self.albumId = albumId
    }
    
    func loadSongs() async {
        isLoading = true
        
        // 1. Try Local Fetch
        songs = (try? await repo.getSongs(for: albumId)) ?? []
        
        // 2. If empty, Sync from Network
        if songs.isEmpty {
            logger.info("⚠️ No songs locally. Syncing details...")
            do {
                try await repo.syncAlbumDetails(albumId: albumId)
                // 3. Fetch again after sync
                songs = (try? await repo.getSongs(for: albumId)) ?? []
            } catch {
                logger.error("❌ Failed to sync album details: \(error)")
            }
        }
        
        // Update Title Helper
        // Update the default title assignment
        if let first = songs.first, let album = first.album {
            self.albumTitle = album.title
        } else {
            // ✅ Modern Localization
            self.albumTitle = String(localized: "Unknown Album", comment: "Default title when album metadata is missing")
        }
        
        isLoading = false
    }
    
    func getQueue() -> [String] {
        songs.map { $0.id }
    }
}

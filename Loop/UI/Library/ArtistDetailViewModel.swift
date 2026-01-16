//
//  ArtistDetailViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation

@Observable @MainActor
final class ArtistDetailViewModel {
    
    var artist: Loop.Artist?
    var albums: [Loop.Album] = []
    var isLoading = false
    
    private let artistId: String
    private let repo: MusicRepository
    
    init(artistId: String, repo: MusicRepository) {
        self.artistId = artistId
        self.repo = repo
    }
    
    func load() async {
        isLoading = true
        do {
            // ✅ FIX: Correctly call the method on MusicRepository
            let result = try await repo.getArtistWithAlbums(id: artistId)
            self.artist = result.artist
            self.albums = result.albums
        } catch {
            print("Failed to load artist: \(error)")
        }
        isLoading = false
    }
}

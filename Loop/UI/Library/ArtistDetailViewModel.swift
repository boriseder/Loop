//
//  ArtistDetailViewModel.swift
//  Loop
//
//  Fixed: Added missing 'isLoading' property
//

import Foundation
import Observation

@Observable @MainActor
final class ArtistDetailViewModel {
    
    var artist: Loop.Artist?
    var albums: [Loop.Album] = []
    var isLoading = false // ✅ ADDED
    
    private let artistId: String
    private let repo: MusicRepository
    
    init(artistId: String, repo: MusicRepository) {
        self.artistId = artistId
        self.repo = repo
    }
    
    func load() async {
        isLoading = true // ✅ Start loading
        do {
            // Fetch artist and albums synchronously from local repo
            let result = try repo.getArtistWithAlbums(id: artistId)
            self.artist = result.artist
            self.albums = result.albums
        } catch {
            print("Error loading artist: \(error)")
        }
        isLoading = false // ✅ Stop loading
    }
}

//
//  ArtistDetailViewModel.swift
//  Loop
//
//  FIXED: Uses MusicEnvironment, async operations
//

import Foundation
import Observation

@Observable @MainActor
final class ArtistDetailViewModel {
    
    var artist: ArtistDTO?
    var albums: [AlbumDTO] = []
    var isLoading = false
    
    private let artistId: String
    private let music: MusicEnvironment
    
    init(artistId: String, music: MusicEnvironment) {
        self.artistId = artistId
        self.music = music
    }
    
    func load() async {
        isLoading = true
        do {
            self.artist = try await music.getArtist(id: artistId)
            self.albums = try await music.getAlbums(forArtist: artistId)
        } catch {
            print("Error loading artist: \(error)")
        }
        isLoading = false
    }
}

//
//  GenreDetailViewModel.swift
//  Loop
//
//  FIXED: Uses MusicEnvironment, async operations
//

import Foundation
import Observation

@Observable @MainActor
final class GenreDetailViewModel {
    
    var albums: [AlbumDTO] = []
    var isLoading = false
    let genreName: String
    
    private let music: MusicEnvironment
    
    init(genreName: String, music: MusicEnvironment) {
        self.genreName = genreName
        self.music = music
    }
    
    func load() async {
        isLoading = true
        do {
            self.albums = try await music.getAlbums(forGenre: genreName)
        } catch {
            print("Error loading genre: \(error)")
        }
        isLoading = false
    }
}

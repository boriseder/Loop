//
//  GenreDetailViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation

@Observable @MainActor
final class GenreDetailViewModel {
    
    var albums: [Loop.Album] = []
    var isLoading = false
    
    // ✅ FIX: Removed 'private' so the View can access it
    let genreName: String
    private let repo: MusicRepository
    
    init(genreName: String, repo: MusicRepository) {
        self.genreName = genreName
        self.repo = repo
    }
    
    func load() async {
        isLoading = true
        do {
            self.albums = try await repo.getAlbums(forGenre: genreName)
        } catch {
            print("Failed to load genre: \(error)")
        }
        isLoading = false
    }
}

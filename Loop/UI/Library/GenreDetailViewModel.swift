//
//  GenreDetailViewModel.swift
//  Loop
//
//  Fixed: Exposed 'genreName' to the View
//

import Foundation
import Observation

@Observable @MainActor
final class GenreDetailViewModel {
    
    var albums: [Loop.Album] = []
    var isLoading = false
    
    // ✅ FIX: Removed 'private' so the View can access it (e.g. for .navigationTitle)
    let genreName: String
    
    private let repo: MusicRepository
    
    init(genreName: String, repo: MusicRepository) {
        self.genreName = genreName
        self.repo = repo
    }
    
    func load() async {
        isLoading = true
        do {
            self.albums = try repo.getAlbums(forGenre: genreName)
        } catch {
            print("Error loading genre: \(error)")
        }
        isLoading = false
    }
}

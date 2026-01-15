//
//  GenreDetailViewModel.swift
//  Loop
//
//  Created by Boris Eder on 15.01.26.
//


//
//  GenreDetailViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation
import OSLog

@Observable @MainActor
final class GenreDetailViewModel {
    
    var genreName: String
    var albums: [Loop.Album] = []
    var isLoading = false
    
    private let repo: MusicRepository
    private let logger = Logger(subsystem: "com.loopapp", category: "GenreDetail")
    
    init(genreName: String, repo: MusicRepository) {
        self.genreName = genreName
        self.repo = repo
    }
    
    func load() async {
        isLoading = true
        do {
            self.albums = try await repo.getAlbums(forGenre: genreName)
        } catch {
            logger.error("Failed to load albums for genre \(self.genreName): \(error)")
        }
        isLoading = false
    }
}
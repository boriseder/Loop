//
//  ArtistDetailViewModel.swift
//  Loop
//
//  Created by Boris Eder on 15.01.26.
//


//
//  ArtistDetailViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation
import OSLog

@Observable @MainActor
final class ArtistDetailViewModel {
    
    var artistName: String = ""
    var albums: [Album] = []
    var isLoading = false
    
    private let artistId: String
    private let repo: MusicRepository
    private let logger = Logger(subsystem: "com.loopapp", category: "ArtistDetail")
    
    init(artistId: String, repo: MusicRepository) {
        self.artistId = artistId
        self.repo = repo
    }
    
    func load() async {
        isLoading = true
        do {
            let (artist, albums) = try await repo.getArtistWithAlbums(id: artistId)
            if let artist {
                self.artistName = artist.name
            }
            self.albums = albums
        } catch {
            logger.error("Failed to load artist: \(error)")
        }
        isLoading = false
    }
}
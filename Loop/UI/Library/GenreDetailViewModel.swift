//
//  GenreDetailViewModel.swift
//  Loop
//
//  FIXED: Uses Global Download State for filtering
//

import Foundation
import Observation

@Observable @MainActor
final class GenreDetailViewModel {
    
    var albums: [AlbumDTO] = []
    var isLoading = false
    
    let genreName: String
    let showDownloadedOnly: Bool
    
    private let music: MusicEnvironment
    
    init(genreName: String, showDownloadedOnly: Bool, music: MusicEnvironment) {
        self.genreName = genreName
        self.showDownloadedOnly = showDownloadedOnly
        self.music = music
    }
    
    func load() async {
        isLoading = true
        do {
            // 1. Get all albums for this genre from DB
            let allAlbums = try await music.getAlbums(forGenre: genreName)
            
            // 2. Filter using Global State if needed
            if showDownloadedOnly {
                self.albums = allAlbums.filter { music.downloadedAlbumIds.contains($0.id) }
            } else {
                self.albums = allAlbums
            }
            
        } catch {
            print("Error loading genre: \(error)")
        }
        isLoading = false
    }
}

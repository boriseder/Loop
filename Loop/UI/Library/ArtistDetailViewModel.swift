//
//  ArtistDetailViewModel.swift
//  Loop
//
//  FIXED: Respects "Downloaded Only" filter
//

import Foundation
import Observation

@Observable @MainActor
final class ArtistDetailViewModel {
    
    var artist: ArtistDTO?
    var albums: [AlbumDTO] = []
    var isLoading = false
    
    private let artistId: String
    private let showDownloadedOnly: Bool
    private let music: MusicEnvironment
    
    init(artistId: String, showDownloadedOnly: Bool, music: MusicEnvironment) {
        self.artistId = artistId
        self.showDownloadedOnly = showDownloadedOnly
        self.music = music
    }
    
    func load() async {
        isLoading = true
        do {
            self.artist = try await music.getArtist(id: artistId)
            let allAlbums = try await music.getAlbums(forArtist: artistId)
            
            // ✅ FILTER: Only show downloaded albums if flag is set
            if showDownloadedOnly {
                self.albums = allAlbums.filter { music.downloadedAlbumIds.contains($0.id) }
            } else {
                self.albums = allAlbums
            }
            
        } catch {
            print("Error loading artist: \(error)")
        }
        isLoading = false
    }
}

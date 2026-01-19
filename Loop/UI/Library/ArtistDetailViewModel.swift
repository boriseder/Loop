import Foundation
import Observation

@Observable @MainActor
final class ArtistDetailViewModel {
    var artist: ArtistDTO?
    var albums: [AlbumDTO] = []
    
    private let artistId: String
    private let showDownloadedOnly: Bool
    private let repo: MusicRepository
    private let downloader: DownloadManager
    
    init(artistId: String, showDownloadedOnly: Bool, repo: MusicRepository, downloader: DownloadManager) {
        self.artistId = artistId
        self.showDownloadedOnly = showDownloadedOnly
        self.repo = repo
        self.downloader = downloader
    }
    
    func load() async {
        do {
            self.artist = try await repo.getArtist(id: artistId)
            let allAlbums = try await repo.getAlbums(forArtist: artistId)
            
            if showDownloadedOnly {
                // Filter albums that have at least one song downloaded
                // This is an expensive check, so we do it carefully
                var filtered: [AlbumDTO] = []
                for album in allAlbums {
                    if await isAlbumDownloaded(album.id) {
                        filtered.append(album)
                    }
                }
                self.albums = filtered
            } else {
                self.albums = allAlbums
            }
        } catch {
            print("Error loading artist: \(error)")
        }
    }
    
    private func isAlbumDownloaded(_ albumId: String) async -> Bool {
        // Check if any song in the album exists on disk
        guard let songs = try? await repo.getSongs(for: albumId) else { return false }
        return songs.contains { downloader.isDownloaded(songId: $0.id) }
    }
}

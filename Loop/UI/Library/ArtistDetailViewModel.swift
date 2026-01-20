import Foundation
import Observation

@Observable @MainActor
final class ArtistDetailViewModel {
    var artist: ArtistDTO?
    var albums: [AlbumDTO] = []
    
    private let artistId: String
    private let repo: MusicRepository
    private let downloader: DownloadManager
    private let filter: DownloadFilter
    
    init(artistId: String, repo: MusicRepository, downloader: DownloadManager, filter: DownloadFilter) {
        self.artistId = artistId
        self.repo = repo
        self.downloader = downloader
        self.filter = filter
    }
    
    func load() async {
        do {
            self.artist = try await repo.getArtist(id: artistId)
            let allAlbums = try await repo.getAlbums(forArtist: artistId)
            
            if filter.showDownloadedOnly {
                // Filter albums that have at least one song downloaded
                var filtered: [AlbumDTO] = []
                for album in allAlbums {
                    if await isAlbumDownloaded(album.id) {
                        filtered.append(album)
                    }
                }
                self.albums = filtered
                print("🔍 Artist albums filtered: \(filtered.count)/\(allAlbums.count)")
            } else {
                self.albums = allAlbums
            }
        } catch {
            print("Error loading artist: \(error)")
        }
    }
    
    private func isAlbumDownloaded(_ albumId: String) async -> Bool {
        guard let songs = try? await repo.getSongs(for: albumId) else { return false }
        return songs.contains { downloader.isDownloaded(songId: $0.id) }
    }
}

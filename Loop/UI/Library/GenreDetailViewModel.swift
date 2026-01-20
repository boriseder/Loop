import Foundation
import Observation

@Observable @MainActor
final class GenreDetailViewModel {
    var albums: [AlbumDTO] = []
    let genreName: String
    
    private let repo: MusicRepository
    private let downloader: DownloadManager
    private let filter: DownloadFilter
    
    init(genreName: String, repo: MusicRepository, downloader: DownloadManager, filter: DownloadFilter) {
        self.genreName = genreName
        self.repo = repo
        self.downloader = downloader
        self.filter = filter
    }
    
    func load() async {
        do {
            let allAlbums = try await repo.getAlbums(forGenre: genreName)
            
            if filter.showDownloadedOnly {
                // Filter albums that have at least one song downloaded
                var filtered: [AlbumDTO] = []
                for album in allAlbums {
                    if await isAlbumDownloaded(album.id) {
                        filtered.append(album)
                    }
                }
                self.albums = filtered
                print("🔍 Genre albums filtered: \(filtered.count)/\(allAlbums.count)")
            } else {
                self.albums = allAlbums
            }
        } catch {
            print("Error loading genre: \(error)")
        }
    }
    
    private func isAlbumDownloaded(_ albumId: String) async -> Bool {
        guard let songs = try? await repo.getSongs(for: albumId) else { return false }
        return songs.contains { downloader.isDownloaded(songId: $0.id) }
    }
}

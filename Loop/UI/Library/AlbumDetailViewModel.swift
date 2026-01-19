import Foundation
import Observation

@Observable @MainActor
final class AlbumDetailViewModel {
    var album: AlbumDTO?
    var songs: [SongDTO] = []
    var isDownloading = false
    
    private let albumId: String
    private let repo: MusicRepository
    private let sync: SyncManager
    private let downloader: DownloadManager
    private let audio: AudioEngine
    
    init(albumId: String, repo: MusicRepository, sync: SyncManager, downloader: DownloadManager, audio: AudioEngine) {
        self.albumId = albumId
        self.repo = repo
        self.sync = sync
        self.downloader = downloader
        self.audio = audio
    }
    
    func load() async {
        do {
            self.album = try repo.getAlbum(id: albumId)
            self.songs = try repo.getSongs(for: albumId)
            
            // Check if we need to fetch details from server (background)
            if songs.isEmpty {
                try? await sync.syncAlbumDetails(albumId)
                // Reload after sync
                self.songs = try repo.getSongs(for: albumId)
            }
        } catch {
            print("Error loading album: \(error)")
        }
    }
    
    func play(song: SongDTO) async {
        let queue = songs.map { $0.id }
        await audio.play(songId: song.id, contextQueue: queue)
    }
    
    func downloadAlbum() {
        isDownloading = true
        Task {
            for song in songs {
                await downloader.downloadSong(song: song)
            }
            isDownloading = false
        }
    }
    
    func isDownloaded() -> Bool {
        guard !songs.isEmpty else { return false }
        return songs.allSatisfy { downloader.isDownloaded(songId: $0.id) }
    }
}

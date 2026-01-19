import Foundation
import Observation

@Observable @MainActor
final class AlbumDetailViewModel {
    var album: AlbumDTO?
    var songs: [SongDTO] = []
    var isDownloading = false
    var downloadProgress: Double = 0.0
    
    private let albumId: String
    private let repo: MusicRepository
    private let sync: SyncManager
    public let downloader: DownloadManager
    private let audio: AudioEngine
    
    private var downloadTask: Task<Void, Never>?
    
    init(albumId: String, repo: MusicRepository, sync: SyncManager, downloader: DownloadManager, audio: AudioEngine) {
        self.albumId = albumId
        self.repo = repo
        self.sync = sync
        self.downloader = downloader
        self.audio = audio
    }
    
    func load() async {
        do {
            // Load from DB first (fast)
            self.album = try await repo.getAlbum(id: albumId)
            self.songs = try await repo.getSongs(for: albumId)
            
            // If no songs, fetch from server in background
            if songs.isEmpty {
                try? await sync.syncAlbumDetails(albumId)
                
                // Reload after sync
                self.songs = try await repo.getSongs(for: albumId)
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
        // Cancel any existing download
        downloadTask?.cancel()
        
        isDownloading = true
        downloadProgress = 0.0
        
        downloadTask = Task {
            let total = songs.count
            var completed = 0
            
            for song in songs {
                guard !Task.isCancelled else {
                    isDownloading = false
                    return
                }
                
                // Only download if not already downloaded
                if !downloader.isDownloaded(songId: song.id) {
                    downloader.downloadSong(song: song)
                    
                    // Wait for this song to complete before starting next
                    // This prevents overwhelming the system
                    while downloader.activeDownloads[song.id] != nil {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled else {
                            isDownloading = false
                            return
                        }
                    }
                }
                
                completed += 1
                downloadProgress = Double(completed) / Double(total)
            }
            
            isDownloading = false
            downloadProgress = 1.0
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        downloadProgress = 0.0
    }
    
    func isDownloaded() -> Bool {
        guard !songs.isEmpty else { return false }
        return songs.allSatisfy { downloader.isDownloaded(songId: $0.id) }
    }
}

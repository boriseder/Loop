import Foundation
import Observation

@Observable @MainActor
final class AlbumDetailViewModel {
    var album: AlbumDTO?
    var songs: [SongDTO] = []
    var isDownloading = false
    var downloadProgress: Double = 0.0
    var showDeleteConfirmation = false
    var downloadedSongIds: Set<String> = []  // Track which songs are downloaded
    
    private let albumId: String
    private let repo: MusicRepository
    private let sync: SyncManager
    public let downloader: DownloadManager
    public let audio: AudioEngine  // Make public so view can access for now playing state
    
    private var downloadTask: Task<Void, Never>?
    private var progressTimer: Timer?
    
    init(albumId: String, repo: MusicRepository, sync: SyncManager, downloader: DownloadManager, audio: AudioEngine) {
        self.albumId = albumId
        self.repo = repo
        self.sync = sync
        self.downloader = downloader
        self.audio = audio
    }
    
    func load() async {
        print("📀 AlbumDetailVM: Loading album \(albumId)")
        do {
            // Load from DB first (fast)
            self.album = try await repo.getAlbum(id: albumId)
            self.songs = try await repo.getSongs(for: albumId)
            
            print("✅ AlbumDetailVM: Loaded \(songs.count) songs from DB")
            
            // Update downloaded songs set
            updateDownloadedSongs()
            
            // If no songs, fetch from server in background
            if songs.isEmpty {
                print("⚠️ AlbumDetailVM: No songs in DB, syncing from server")
                try? await sync.syncAlbumDetails(albumId)
                
                // Reload after sync
                self.songs = try await repo.getSongs(for: albumId)
                print("✅ AlbumDetailVM: Loaded \(songs.count) songs after sync")
                updateDownloadedSongs()
            }
        } catch {
            print("❌ AlbumDetailVM: Error loading album: \(error)")
        }
    }
    
    private func updateDownloadedSongs() {
        downloadedSongIds = Set(songs.filter { downloader.isDownloaded(songId: $0.id) }.map { $0.id })
        print("📊 AlbumDetailVM: \(downloadedSongIds.count)/\(songs.count) songs downloaded")
    }
    
    func play(song: SongDTO) async {
        print("▶️ AlbumDetailVM: Playing song \(song.title) (ID: \(song.id))")
        let queue = songs.map { $0.id }
        print("📋 AlbumDetailVM: Queue has \(queue.count) songs")
        await audio.play(songId: song.id, contextQueue: queue)
    }
    
    func downloadAlbum() {
        print("⬇️ AlbumDetailVM: Starting album download")
        // Cancel any existing download
        downloadTask?.cancel()
        progressTimer?.invalidate()
        
        isDownloading = true
        downloadProgress = 0.0
        
        // Start progress monitoring timer - checks every 200ms
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isDownloading else { return }
                
                // Update downloaded songs set
                self.updateDownloadedSongs()
                
                // Calculate progress
                let total = Double(self.songs.count)
                let completed = Double(self.downloadedSongIds.count)
                self.downloadProgress = total > 0 ? completed / total : 0
                
                print("📊 Progress: \(self.downloadedSongIds.count)/\(self.songs.count) = \(Int(self.downloadProgress * 100))%")
            }
        }
        
        downloadTask = Task { @MainActor in
            for song in songs {
                guard !Task.isCancelled else {
                    stopDownloading()
                    return
                }
                
                // Skip if already downloaded
                if downloader.isDownloaded(songId: song.id) {
                    print("⏭️ AlbumDetailVM: Song \(song.title) already downloaded, skipping")
                    downloadedSongIds.insert(song.id)
                    continue
                }
                
                print("⬇️ AlbumDetailVM: Queueing download for \(song.title)")
                downloader.downloadSong(song: song)
                
                // Wait for download to appear in activeDownloads (max 1 second)
                var waitCount = 0
                while downloader.activeDownloads[song.id] == nil && waitCount < 10 {
                    try? await Task.sleep(for: .milliseconds(100))
                    waitCount += 1
                }
                
                if downloader.activeDownloads[song.id] == nil {
                    print("⚠️ AlbumDetailVM: Download didn't start for \(song.title)")
                    continue
                }
                
                print("⏳ AlbumDetailVM: Waiting for \(song.title) to complete...")
                
                // Now wait for it to complete
                while downloader.activeDownloads[song.id] != nil {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else {
                        stopDownloading()
                        return
                    }
                }
                
                // Verify download succeeded
                if downloader.isDownloaded(songId: song.id) {
                    print("✅ AlbumDetailVM: \(song.title) downloaded successfully")
                    downloadedSongIds.insert(song.id)
                } else {
                    print("❌ AlbumDetailVM: \(song.title) download failed")
                }
            }
            
            stopDownloading()
            print("✅ AlbumDetailVM: Album download complete - \(downloadedSongIds.count)/\(songs.count) songs")
        }
    }
    
    private func stopDownloading() {
        progressTimer?.invalidate()
        progressTimer = nil
        isDownloading = false
        
        // Final update of downloaded songs
        updateDownloadedSongs()
        
        // Final progress calculation
        let total = Double(songs.count)
        let completed = Double(downloadedSongIds.count)
        downloadProgress = total > 0 ? completed / total : 0
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        stopDownloading()
    }
    
    func deleteAlbum() {
        let songIds = songs.map { $0.id }
        downloader.deleteAlbumDownloads(songIds: songIds)
        downloadedSongIds.removeAll()
        downloadProgress = 0.0
    }
    
    func isDownloaded() -> Bool {
        guard !songs.isEmpty else { return false }
        return downloadedSongIds.count == songs.count
    }
    
    func isSongDownloaded(_ songId: String) -> Bool {
        return downloadedSongIds.contains(songId)
    }
}

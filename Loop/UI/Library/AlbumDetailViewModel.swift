import Foundation
import Observation

@Observable @MainActor
final class AlbumDetailViewModel {
    var album: AlbumDTO?
    var songs: [SongDTO] = []
    var isDownloading = false
    var downloadProgress: Double = 0.0
    var showDeleteConfirmation = false
    var downloadedSongIds: Set<String> = []

    private let albumId: String
    private let repo: MusicRepository
    private let sync: SyncManager
    public let downloader: DownloadManager
    public let audio: AudioEngine

    // Needed to resolve stream URLs for downloads
    private let client: NavidromeClient

    private var downloadTask: Task<Void, Never>?
    private var progressTimer: Timer?

    init(
        albumId: String,
        repo: MusicRepository,
        sync: SyncManager,
        downloader: DownloadManager,
        audio: AudioEngine,
        client: NavidromeClient
    ) {
        self.albumId = albumId
        self.repo = repo
        self.sync = sync
        self.downloader = downloader
        self.audio = audio
        self.client = client
    }

    // MARK: - Load

    func load() async {
        do {
            self.album = try await repo.getAlbum(id: albumId)
            self.songs = try await repo.getSongs(for: albumId)
            updateDownloadedSongs()

            if songs.isEmpty {
                try? await sync.syncAlbumDetails(albumId)
                self.songs = try await repo.getSongs(for: albumId)
                updateDownloadedSongs()
            }
        } catch {
            print("❌ AlbumDetailVM: \(error)")
        }
    }

    private func updateDownloadedSongs() {
        downloadedSongIds = Set(songs.filter { downloader.isDownloaded(songId: $0.id) }.map { $0.id })
    }

    // MARK: - Playback

    func play(song: SongDTO) async {
        await audio.play(songId: song.id, contextQueue: songs.map { $0.id })
    }

    // MARK: - Download

    func downloadAlbum() {
        downloadTask?.cancel()
        progressTimer?.invalidate()

        isDownloading = true
        downloadProgress = 0.0

        // Progress polling — reads downloader state and our own downloaded set
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isDownloading else { return }
                self.updateDownloadedSongs()
                let total = Double(self.songs.count)
                let done = Double(self.downloadedSongIds.count)
                self.downloadProgress = total > 0 ? done / total : 0
            }
        }

        downloadTask = Task {
            // Resolve all stream URLs up front (single actor hop into NavidromeClient)
            for song in songs {
                guard !Task.isCancelled else { stopDownloading(); return }
                guard !downloader.isDownloaded(songId: song.id) else { continue }

                // Ask the client for a stream URL — this is the authenticated URL
                guard let url = await client.streamURL(for: song.id) else {
                    print("⚠️ No stream URL for \(song.title)")
                    continue
                }

                // Hand off to DownloadManager; it owns the URLSession from here
                downloader.downloadSong(song: song, streamURL: url)
            }

            // Wait until all active downloads for this album finish or are cancelled
            while !Task.isCancelled {
                let pending = songs.filter { downloader.activeDownloads[$0.id] != nil }
                if pending.isEmpty { break }
                try? await Task.sleep(for: .milliseconds(300))
            }

            stopDownloading()
        }
    }

    private func stopDownloading() {
        progressTimer?.invalidate()
        progressTimer = nil
        isDownloading = false
        updateDownloadedSongs()
        let total = Double(songs.count)
        downloadProgress = total > 0 ? Double(downloadedSongIds.count) / total : 0
    }

    func cancelDownload() {
        downloadTask?.cancel()
        stopDownloading()
    }

    func deleteAlbum() {
        downloader.deleteAlbumDownloads(songIds: songs.map { $0.id })
        downloadedSongIds.removeAll()
        downloadProgress = 0.0
    }

    func isDownloaded() -> Bool {
        guard !songs.isEmpty else { return false }
        return downloadedSongIds.count == songs.count
    }

    func isSongDownloaded(_ songId: String) -> Bool {
        downloadedSongIds.contains(songId)
    }
}

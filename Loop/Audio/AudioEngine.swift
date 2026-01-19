import Foundation
import AVFoundation
import MediaPlayer
import Observation

@Observable @MainActor
final class AudioEngine {
    // MARK: - State
    var isPlaying = false
    var currentSong: SongDTO?
    var progress: Double = 0.0
    var duration: Double = 1.0
    
    // MARK: - Private
    private let player = AVQueuePlayer()
    private let provider: AssetProvider
    private let repo: MusicRepository
    private let coverCache: CoverArtCache
    
    private var queue: [String] = []
    private var currentIndex = 0
    
    // MARK: - Init
    init(provider: AssetProvider, repo: MusicRepository, coverCache: CoverArtCache) {
        self.provider = provider
        self.repo = repo
        self.coverCache = coverCache
        setupSession()
        setupTimer()
        setupRemoteCommands()
    }
    
    private func setupSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    // MARK: - Public Control Methods
    
    func play(songId: String, contextQueue: [String]) async {
        self.queue = contextQueue
        if let idx = queue.firstIndex(of: songId) {
            self.currentIndex = idx
        }
        await loadAndPlayCurrent()
    }
    
    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    func skipToNext() async {
        guard currentIndex < queue.count - 1 else { return }
        currentIndex += 1
        await loadAndPlayCurrent()
    }
    
    func skipToPrevious() async {
        // If we are more than 3 seconds in, restart the song
        if player.currentTime().seconds > 3 {
            // ✅ FIXED: Using async seek
            await player.seek(to: .zero)
            return
        }
        
        // Otherwise go to previous track
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        await loadAndPlayCurrent()
    }
    
    // MARK: - Internal Logic
    
    private func loadAndPlayCurrent() async {
        guard queue.indices.contains(currentIndex) else { return }
        let id = queue[currentIndex]
        
        // 1. Load Metadata
        // ✅ FIXED: Removed 'await' (Repo and Engine are both MainActor, so call is sync)
        if let song = try? repo.getSong(id: id) {
            self.currentSong = song
            updateNowPlayingInfo(song: song)
        }
        
        // 2. Load Audio
        player.pause()
        player.removeAllItems()
        
        if let asset = await provider.asset(for: id) {
            let item = AVPlayerItem(asset: asset)
            player.insert(item, after: nil)
            player.play()
            isPlaying = true
            
            // 3. Load Duration
            if let duration = try? await asset.load(.duration) {
                self.duration = duration.seconds
            }
        }
    }
    
    private func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                self.progress = self.player.currentTime().seconds
            }
        }
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { await self?.skipToNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { await self?.skipToPrevious() }
            return .success
        }
    }
    
    private func updateNowPlayingInfo(song: SongDTO) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistName ?? "Unknown",
            MPMediaItemPropertyAlbumTitle: song.albumTitle ?? ""
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Load cover art asynchronously
        Task {
            if let cid = song.coverArtId,
               let img = await coverCache.image(for: cid, size: 500) {
                let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
}

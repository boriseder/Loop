import Foundation
import AVFoundation
import MediaPlayer
import Observation

// MARK: - Audio Engine (MainActor only for @Observable state)
@Observable @MainActor
final class AudioEngine {
    // MARK: - Published State (UI reads these)
    private(set) var isPlaying = false
    private(set) var currentSong: SongDTO?
    private(set) var progress: Double = 0.0
    private(set) var duration: Double = 1.0
    
    // MARK: - Private Dependencies
    private let player = AVQueuePlayer()
    private let provider: AssetProvider
    private let repo: MusicRepository
    private let coverCache: CoverArtCache
    
    // MARK: - Internal State (accessed from background)
    private let stateActor = PlaybackStateActor()
    
    // MARK: - Timer Management
    private var progressTimer: Timer?
    
    // MARK: - Init
    init(provider: AssetProvider, repo: MusicRepository, coverCache: CoverArtCache) {
        self.provider = provider
        self.repo = repo
        self.coverCache = coverCache
        setupSession()
        setupRemoteCommands()
        startProgressTimer()
    }
    
    deinit {
        progressTimer?.invalidate()
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    // MARK: - Setup
    private func setupSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.progress = self.player.currentTime().seconds
            }
        }
    }
    
    // MARK: - Public Control Methods
    func play(songId: String, contextQueue: [String]) async {
        // Update actor state first (thread-safe)
        await stateActor.setQueue(contextQueue, currentId: songId)
        
        // Load and play
        await loadAndPlayCurrent(songId: songId)
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
        guard let nextId = await stateActor.nextSong() else { return }
        await loadAndPlayCurrent(songId: nextId)
    }
    
    func skipToPrevious() async {
        // If more than 3 seconds in, restart current song
        if player.currentTime().seconds > 3 {
            await player.seek(to: .zero)
            return
        }
        
        // Otherwise go to previous
        guard let prevId = await stateActor.previousSong() else { return }
        await loadAndPlayCurrent(songId: prevId)
    }
    
    // MARK: - Internal Loading Logic
    private func loadAndPlayCurrent(songId: String) async {
        // 1. Load metadata (repo call is now off MainActor)
        let song = await Task.detached { [repo] in
            try? await repo.getSong(id: songId)
        }.value
        
        guard let song else { return }
        
        // 2. Update UI state
        self.currentSong = song
        
        // 3. Update Now Playing (can be async)
        Task {
            await updateNowPlayingInfo(song: song)
        }
        
        // 4. Load audio asset (off MainActor)
        let asset = await provider.asset(for: songId)
        guard let asset else { return }
        
        // 5. Replace player item
        player.pause()
        player.removeAllItems()
        
        let item = AVPlayerItem(asset: asset)
        player.insert(item, after: nil)
        player.play()
        isPlaying = true
        
        // 6. Load duration
        if let durationValue = try? await asset.load(.duration) {
            self.duration = durationValue.seconds
        }
    }
    
    // MARK: - Remote Commands
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { await self.skipToNext() }
            return .success
        }
        
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { await self.skipToPrevious() }
            return .success
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo(song: SongDTO) async {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistName ?? "Unknown",
            MPMediaItemPropertyAlbumTitle: song.albumTitle ?? ""
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Load cover art asynchronously
        if let cid = song.coverArtId,
           let img = await coverCache.image(for: cid, size: 500) {
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}

// MARK: - Thread-Safe Queue State Actor
private actor PlaybackStateActor {
    private var queue: [String] = []
    private var currentIndex = 0
    
    func setQueue(_ newQueue: [String], currentId: String) {
        self.queue = newQueue
        self.currentIndex = newQueue.firstIndex(of: currentId) ?? 0
    }
    
    func nextSong() -> String? {
        guard currentIndex < queue.count - 1 else { return nil }
        currentIndex += 1
        return queue[currentIndex]
    }
    
    func previousSong() -> String? {
        guard currentIndex > 0 else { return nil }
        currentIndex -= 1
        return queue[currentIndex]
    }
}

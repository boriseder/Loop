import Foundation
import AVFoundation
import MediaPlayer
import Observation

// MARK: - Audio Engine
@Observable @MainActor
final class AudioEngine {

    // MARK: - Public State (UI reads these)
    private(set) var isPlaying = false
    private(set) var currentSong: SongDTO?
    private(set) var progress: Double = 0.0
    private(set) var duration: Double = 1.0
    private(set) var isShuffled: Bool = false
    private(set) var repeatMode: RepeatMode = .off

    // MARK: - Private Dependencies
    private let player = AVQueuePlayer()
    private let provider: any AssetProvider
    private let repo: MusicRepository
    private let coverCache: CoverArtCache

    // MARK: - Queue
    private let queue = PlaybackQueue()

    // MARK: - Observation / Timers
    private var progressTimer: Timer?
    private var endObserver: NSObjectProtocol?

    // MARK: - Remote Command targets (kept alive)
    private var commandTargets: [Any] = []

    // MARK: - Init

    init(provider: AssetProvider, repo: MusicRepository, coverCache: CoverArtCache) {
        self.provider = provider
        self.repo = repo
        self.coverCache = coverCache
        setupAudioSession()
        setupRemoteCommands()
        setupEndOfItemObserver()
        startProgressTimer()
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            teardown()
        }
    }

    // MARK: - Public Control

    /// Begin playback of `songId`, using `contextQueue` as the full ordered queue.
    func play(songId: String, contextQueue: [String]) async {
        await queue.setQueue(contextQueue, startingAt: songId)
        isShuffled = await queue.isShuffled
        repeatMode = await queue.repeatMode
        await replacePlayerAndPlay(songId: songId, preloadNext: true)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlayingPlaybackState()
    }

    func skipToNext() async {
        guard let nextId = await queue.advance() else {
            // Queue exhausted (repeat is off)
            player.pause()
            isPlaying = false
            return
        }
        await replacePlayerAndPlay(songId: nextId, preloadNext: true)
    }

    func skipToPrevious() async {
        // If we're more than 3 s into a track, restart it instead of going back.
        if player.currentTime().seconds > 3 {
            await seekTo(seconds: 0)
            return
        }
        guard let prevId = await queue.stepBack() else { return }
        await replacePlayerAndPlay(songId: prevId, preloadNext: true)
    }

    func seekTo(seconds: Double) async {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        await player.seek(to: time)
        progress = seconds
        updateNowPlayingElapsed()
    }

    // MARK: - Shuffle / Repeat

    func toggleShuffle() async {
        await queue.toggleShuffle()
        isShuffled = await queue.isShuffled
        // Re-prime the upcoming queue item so the pre-loaded next item is correct.
        await reprimeNextItem()
    }

    func cycleRepeatMode() async {
        await queue.cycleRepeatMode()
        repeatMode = await queue.repeatMode
        await reprimeNextItem()
    }

    // MARK: - Setup helpers

    private func setupAudioSession() {
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
                self.updateNowPlayingElapsed()
            }
        }
    }

    /// Observes AVQueuePlayer advancing to the next item naturally (gapless transition).
    /// When that happens we update our state actor and enqueue the item *after* that.
    private func setupEndOfItemObserver() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.handleItemDidPlayToEnd()
            }
        }
    }

    private func teardown() {
        progressTimer?.invalidate()
        progressTimer = nil
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        removeRemoteCommandTargets()
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    // MARK: - Core playback logic

    /// Called when the current item finishes playing naturally (the player has already
    /// advanced to the pre-loaded next item inside AVQueuePlayer).
    private func handleItemDidPlayToEnd() async {
        // Advance our logical state to match what the player already did.
        guard let nextId = await queue.advance() else {
            // Queue finished and repeat is off.
            isPlaying = false
            return
        }

        // Update metadata for the song that is now current.
        await refreshCurrentSongMetadata(songId: nextId)

        // Enqueue the *next-next* item so the player always has one item ahead.
        await appendNextItemToPlayer()
    }

    /// Fully replaces the player's queue and starts playing `songId`.
    /// If `preloadNext` is true the next song is pre-loaded into AVQueuePlayer
    /// immediately so the transition will be gapless.
    private func replacePlayerAndPlay(songId: String, preloadNext: Bool) async {
        // 1. Load asset for the current song.
        async let assetFetch = provider.asset(for: songId)
        async let songFetch: SongDTO? = Task.detached { [repo] in
            try? await repo.getSong(id: songId)
        }.value

        let (asset, song) = await (assetFetch, songFetch)

        guard let asset, let song else {
            print("❌ AudioEngine: Failed to load song \(songId)")
            return
        }

        // 2. Swap player items.
        player.pause()
        player.removeAllItems()

        let currentItem = AVPlayerItem(asset: asset)
        player.insert(currentItem, after: nil)

        // 3. Update observable state.
        self.currentSong = song
        self.progress = 0
        self.duration = song.duration > 0 ? song.duration : 1

        // 4. Start playing immediately for zero-latency feel.
        player.play()
        isPlaying = true

        // 5. Update lock-screen / Control Centre.
        Task { await updateNowPlayingInfo(song: song) }

        // 6. Asynchronously load the precise duration once the asset is ready.
        Task {
            if let d = try? await asset.load(.duration), d.isNumeric {
                self.duration = d.seconds
            }
        }

        // 7. Pre-load the next song into AVQueuePlayer for gapless playback.
        if preloadNext {
            await appendNextItemToPlayer()
        }
    }

    /// Appends the next song's AVPlayerItem to AVQueuePlayer (without touching the current item).
    /// This is what gives us gapless playback — AVQueuePlayer crossfades/splices automatically.
    private func appendNextItemToPlayer() async {
        guard let nextId = await queue.nextSongId else { return }

        // Fetch the asset in the background — this is the key to gapless:
        // we do it *while the current song is still playing*.
        guard let nextAsset = await provider.asset(for: nextId) else { return }

        let nextItem = AVPlayerItem(asset: nextAsset)
        // Only append if it won't duplicate (player might already have it)
        if player.items().count < 2 {
            player.insert(nextItem, after: player.items().last)
        }
    }

    /// Re-fetches and appends the next item — called after shuffle/repeat changes
    /// so the pre-loaded queue slot is always correct.
    private func reprimeNextItem() async {
        // Remove any pre-loaded items beyond the current one.
        let items = player.items()
        if items.count > 1 {
            for item in items.dropFirst() {
                player.remove(item)
            }
        }
        await appendNextItemToPlayer()
    }

    /// Updates `currentSong` from the database (used after a natural transition).
    private func refreshCurrentSongMetadata(songId: String) async {
        let song = await Task.detached { [repo] in
            try? await repo.getSong(id: songId)
        }.value

        guard let song else { return }
        self.currentSong = song
        self.progress = 0
        self.duration = song.duration > 0 ? song.duration : 1

        Task { await updateNowPlayingInfo(song: song) }
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        let play = center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.togglePlayPause() }
            return .success
        }

        let pause = center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.togglePlayPause() }
            return .success
        }

        let next = center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in await self.skipToNext() }
            return .success
        }

        let prev = center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in await self.skipToPrevious() }
            return .success
        }

        let changePos = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in await self.seekTo(seconds: e.positionTime) }
            return .success
        }

        commandTargets = [play, pause, next, prev, changePos]
    }

    private func removeRemoteCommandTargets() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        commandTargets.removeAll()
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo(song: SongDTO) async {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistName ?? "Unknown",
            MPMediaItemPropertyAlbumTitle: song.albumTitle ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if let cid = song.coverArtId,
           let img = await coverCache.image(for: cid, size: 500) {
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    private func updateNowPlayingPlaybackState() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

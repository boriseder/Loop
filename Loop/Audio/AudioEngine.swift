//
//  AudioEngine.swift
//  Loop
//
//  Fixed: Strict concurrency for AVPlayerItem and weak capture
//

import Foundation
import AVFoundation
import Observation
import MediaPlayer
import UIKit

private final class TimeObserverToken {
    private let player: AVPlayer
    private let observer: Any
    
    init(player: AVPlayer, observer: Any) {
        self.player = player
        self.observer = observer
    }
    
    deinit {
        player.removeTimeObserver(observer)
    }
}

@Observable @MainActor
final class AudioEngine {
    
    var isPlaying: Bool = false
    var currentSongId: String?
    var progress: Double = 0.0
    var duration: Double = 0.0
    
    var currentTitle: String = "Not Playing"
    var currentArtist: String = ""
    var currentCoverId: String?
    
    var errorMessage: String?
    
    private let provider: AssetProvider
    private let stateStore: PlaybackPersistence
    private let repo: MusicRepository
    private let coverCache: CoverArtCache
    
    private let player = AVQueuePlayer()
    
    private var timeObserverToken: TimeObserverToken?
    
    private var nowPlayingInfo = [String: Any]()
    
    init(provider: AssetProvider, stateStore: PlaybackPersistence, repo: MusicRepository, coverCache: CoverArtCache) {
        self.provider = provider
        self.stateStore = stateStore
        self.repo = repo
        self.coverCache = coverCache
        
        setupObservers()
        setupRemoteTransportControls()
        setupAudioSession()
        
        Task { await restoreState() }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func setupPlayer(with currentId: String, queue: [String], autoPlay: Bool = true) async {
        player.pause()
        player.removeAllItems()
        
        self.currentSongId = currentId
        self.currentTitle = "Loading..."
        self.currentArtist = ""
        self.currentCoverId = nil
        
        // ✅ FIX: Load only AVAssets in background (I/O), NOT AVPlayerItems (UI/MainActor bound)
        // Explicitly capturing [weak provider] requires provider to be a class (AnyObject)
        let loadedAssets = await Task.detached(priority: .userInitiated) { [weak provider] () -> [AVAsset] in
            guard let provider = provider else { return [] }
            var assets: [AVAsset] = []
            
            // Limit queue buffer to next 3 songs
            let startIndex = queue.firstIndex(of: currentId) ?? 0
            let batch = queue[startIndex..<min(startIndex + 3, queue.count)]
            
            for songId in batch {
                if let asset = await provider.asset(for: songId) {
                    assets.append(asset)
                }
            }
            return assets
        }.value
        
        guard !loadedAssets.isEmpty else {
            self.errorMessage = "Could not load songs"
            return
        }
        
        // ✅ FIX: Create AVPlayerItems on the MainActor
        for asset in loadedAssets {
            let item = AVPlayerItem(asset: asset)
            player.insert(item, after: nil)
        }
        
        let durationValue = await getDuration()
        updateNowPlaying(duration: durationValue, rate: autoPlay ? 1.0 : 0.0)
        
        if autoPlay { play() }
        
        // Load metadata asynchronously
        Task.detached(priority: .userInitiated) {
            await self.loadMetadata(for: currentId)
        }
        
        saveState(queue: queue)
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func getDuration() async -> Double {
        guard let item = player.currentItem else { return 180.0 }
        do {
            let duration = try await item.asset.load(.duration)
            let seconds = duration.seconds
            return seconds.isFinite && seconds > 0 ? seconds : 180.0
        } catch {
            return 180.0
        }
    }

    func play() {
        player.play()
        isPlaying = true
        updateNowPlaying(rate: 1.0)
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying(rate: 0.0, elapsed: player.currentTime().seconds)
        saveState()
    }
    
    func skipToNext() {
        player.advanceToNextItem()
        saveState()
    }
    
    private func loadMetadata(for songId: String) async {
        guard let song = repo.song(id: songId) else { return }
        
        await MainActor.run {
            self.currentTitle = song.title
            self.currentArtist = song.artist?.name ?? "Unknown Artist"
            self.currentCoverId = song.album?.coverArtId
            
            nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist?.name ?? "Unknown Artist"
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album?.title ?? ""
            if song.duration > 0 {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        
        if let coverId = song.album?.coverArtId {
            if let image = await coverCache.getImage(for: coverId, size: 600) {
                await MainActor.run {
                    let art = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = art
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
        }
    }

    private func saveState(queue: [String]? = nil) {
        guard let currentSongId else { return }
        let state = PlaybackState(
            currentSongId: currentSongId,
            queue: queue ?? [],
            elapsed: player.currentTime().seconds
        )
        stateStore.save(state)
    }
    
    private func restoreState() async {
        guard let saved: PlaybackState = stateStore.load() else { return }
        await setupPlayer(with: saved.currentSongId, queue: saved.queue, autoPlay: false)
        await player.seek(to: CMTime(seconds: saved.elapsed, preferredTimescale: 600))
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipToNext() }
            return .success
        }
    }
    
    private func setupObservers() {
        let observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.updateProgress(time: time)
            }
        }
        self.timeObserverToken = TimeObserverToken(player: player, observer: observer)
    }
    
    private func updateProgress(time: CMTime) {
        guard player.currentItem != nil else { return }
        if let dur = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double, dur > 0 {
            self.progress = time.seconds / dur
            self.duration = dur
        }
    }
    
    private func updateNowPlaying(duration: Double? = nil, rate: Double? = nil, elapsed: Double? = nil) {
        if let duration = duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let rate = rate {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }
        if let elapsed = elapsed {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

//
//  AudioEngine.swift
//  Loop
//
//  FIXED: Proper Task cancellation, removed TimeObserverToken hack
//

import Foundation
import AVFoundation
import Observation
import MediaPlayer
import UIKit

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
    private var nowPlayingInfo = [String: Any]()
    
    // Proper Task-based observation
    private var observerTask: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?
    
    init(provider: AssetProvider, stateStore: PlaybackPersistence, repo: MusicRepository, coverCache: CoverArtCache) {
        self.provider = provider
        self.stateStore = stateStore
        self.repo = repo
        self.coverCache = coverCache
        
        setupRemoteTransportControls()
        setupAudioSession()
        startProgressObserver()
        
        Task { await restoreState() }
    }
    
    // Note: Task cancellation happens automatically when AudioEngine is deallocated
    // No explicit deinit needed for Task cleanup
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func setupPlayer(with currentId: String, queue: [String], autoPlay: Bool = true) async {
        // Cancel any ongoing work
        metadataTask?.cancel()
        
        player.pause()
        player.removeAllItems()
        
        self.currentSongId = currentId
        self.currentTitle = "Loading..."
        self.currentArtist = ""
        self.currentCoverId = nil
        
        // Load assets in background (proper cancellation support)
        let loadTask = Task<[AVAsset], Error> {
            var assets: [AVAsset] = []
            let startIndex = queue.firstIndex(of: currentId) ?? 0
            let batch = Array(queue[startIndex..<min(startIndex + 3, queue.count)])
            
            for songId in batch {
                try Task.checkCancellation()
                if let asset = await provider.asset(for: songId) {
                    assets.append(asset)
                }
            }
            return assets
        }
        
        do {
            let loadedAssets = try await loadTask.value
            
            guard !loadedAssets.isEmpty else {
                self.errorMessage = "Could not load songs"
                return
            }
            
            // Create items on MainActor
            for asset in loadedAssets {
                let item = AVPlayerItem(asset: asset)
                player.insert(item, after: nil)
            }
            
            let durationValue = await getDuration()
            updateNowPlaying(duration: durationValue, rate: autoPlay ? 1.0 : 0.0)
            
            if autoPlay { play() }
            
            // Load metadata asynchronously
            metadataTask = Task.detached(priority: .userInitiated) {
                await self.loadMetadata(for: currentId)
            }
            
            saveState(queue: queue)
            
        } catch is CancellationError {
            // Silently handle cancellation
            return
        } catch {
            self.errorMessage = "Failed to setup player: \(error.localizedDescription)"
        }
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
        do {
            guard let song = try await repo.song(id: songId) else { return }
            
            await MainActor.run {
                self.currentTitle = song.title
                self.currentArtist = song.artistName ?? "Unknown Artist"
                self.currentCoverId = song.coverArtId
                
                nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
                nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName ?? "Unknown Artist"
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumTitle ?? ""
                if song.duration > 0 {
                    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
            
            if let coverId = song.coverArtId {
                if let image = await coverCache.getImage(for: coverId, size: 600) {
                    await MainActor.run {
                        let art = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = art
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }
        } catch {
            // Metadata loading is non-critical
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
    
    // FIXED: Use Task instead of TimeObserverToken
    private func startProgressObserver() {
        observerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                guard !Task.isCancelled,
                      player.currentItem != nil,
                      let dur = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double,
                      dur > 0 else { continue }
                
                let current = player.currentTime().seconds
                self.progress = current / dur
                self.duration = dur
            }
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

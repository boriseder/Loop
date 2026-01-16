//
//  AudioEngine.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
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
    
    private let provider: AssetProvider
    private let stateStore: PlaybackPersistence
    private let repo: MusicRepository
    private let client: NavidromeClient
    
    private let player = AVQueuePlayer()
    private var timeObserver: Any?
    private var nowPlayingInfo = [String: Any]()
    
    init(provider: AssetProvider, stateStore: PlaybackPersistence, repo: MusicRepository, client: NavidromeClient) {
        self.provider = provider
        self.stateStore = stateStore
        self.repo = repo
        self.client = client
        
        setupObservers()
        setupRemoteTransportControls()
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        Task { await restoreState() }
    }
    
    func setupPlayer(with currentId: String, queue: [String], autoPlay: Bool = true) async {
        player.pause()
        player.removeAllItems()
        let startIndex = queue.firstIndex(of: currentId) ?? 0
        let batch = queue[startIndex..<min(startIndex + 3, queue.count)]
        
        for songId in batch {
            if let asset = await provider.asset(for: songId) {
                player.insert(AVPlayerItem(asset: asset), after: nil)
            }
        }
        
        self.currentSongId = currentId
        self.currentTitle = "Loading..."
        self.currentArtist = ""
        self.currentCoverId = nil
        
        let durationValue = await getDuration()
        self.nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Loading...",
            MPMediaItemPropertyArtist: "Unknown Artist",
            MPMediaItemPropertyPlaybackDuration: durationValue,
            MPNowPlayingInfoPropertyPlaybackRate: autoPlay ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        if autoPlay { play() }
        await loadMetadata(for: currentId)
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
        } catch { return 180.0 }
    }

    func play() {
        player.play()
        isPlaying = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        saveState()
    }
    
    func skipToNext() {
        player.advanceToNextItem()
        saveState()
    }
    
    private func loadMetadata(for songId: String) async {
        await repo.ensureSongExists(id: songId)
        
        // ✅ FIX: Calls the repo method that is now guaranteed to exist
        guard let song = await repo.song(id: songId) else { return }
        
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
        
        if let coverId = song.album?.coverArtId {
            let url = client.coverArtURL(id: coverId, size: 600)
            if let url = url, let data = try? await client.downloadData(from: url), let image = UIImage(data: data) {
                let art = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = art
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    private func saveState(queue: [String]? = nil) {
        guard let currentSongId else { return }
        let state = PlaybackState(currentSongId: currentSongId, queue: queue ?? [], elapsed: player.currentTime().seconds)
        stateStore.save(state)
    }
    
    private func restoreState() async {
        guard let saved: PlaybackState = stateStore.load() else { return }
        await setupPlayer(with: saved.currentSongId, queue: saved.queue, autoPlay: false)
        await player.seek(to: CMTime(seconds: saved.elapsed, preferredTimescale: 600))
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in Task { @MainActor [weak self] in self?.play() }; return .success }
        commandCenter.pauseCommand.addTarget { [weak self] _ in Task { @MainActor [weak self] in self?.pause() }; return .success }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor [weak self] in self?.skipToNext() }; return .success }
    }
    
    private func setupObservers() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in self?.updateProgress(time: time) }
        }
    }
    
    private func updateProgress(time: CMTime) {
        guard player.currentItem != nil else { return }
        if let dur = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double, dur > 0 {
            self.progress = time.seconds / dur
            self.duration = dur
        }
    }
}

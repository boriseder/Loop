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
import UIKit // Needed for UIImage

@Observable @MainActor
final class AudioEngine {
    
    // MARK: - State
    var isPlaying: Bool = false
    var currentSongId: String?
    var progress: Double = 0.0
    var duration: Double = 0.0
    
    // MARK: - Dependencies
    private let provider: AssetProvider
    private let stateStore: PlaybackPersistence
    private let repo: MusicRepository      // ✅ NEW
    private let client: NavidromeClient    // ✅ NEW
    
    private let player = AVQueuePlayer()
    private var timeObserver: Any?
    
    // Lock Screen Info Holder
    private var nowPlayingInfo = [String: Any]()
    
    init(provider: AssetProvider, stateStore: PlaybackPersistence, repo: MusicRepository, client: NavidromeClient) {
        self.provider = provider
        self.stateStore = stateStore
        self.repo = repo
        self.client = client
        
        setupObservers()
        setupRemoteTransportControls()
        
        // Configure Audio Session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio Session Error: \(error)")
        }
    }
    
    // MARK: - Player Actions
    
    func setupPlayer(with currentId: String, queue: [String]) {
        player.pause()
        player.removeAllItems()
        
        // 1. Setup Queue
        let startIndex = queue.firstIndex(of: currentId) ?? 0
        let batch = queue[startIndex..<min(startIndex + 3, queue.count)]
        
        for songId in batch {
            if let asset = provider.asset(for: songId) {
                player.insert(AVPlayerItem(asset: asset), after: nil)
            }
        }
        
        self.currentSongId = currentId
        
        // ✅ FIX: Play FIRST so the system knows we are active
        play()
        
        // ✅ FIX: Update Info immediately AFTER playing
        self.nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Loading...",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // 3. Fetch Rich Metadata (Async)
        Task {
            await loadMetadata(for: currentId)
        }
    }

    func play() {
        player.play()
        isPlaying = true
        updatePlaybackRate() // Update Lock Screen state
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        updatePlaybackRate() // Update Lock Screen state
    }
    
    func skipToNext() {
        player.advanceToNextItem()
        // Note: In a full app, you would determine the next song ID here and call loadMetadata(nextId)
    }
    
    // MARK: - Lock Screen Metadata Logic
    
    private func loadMetadata(for songId: String) async {
        // Fetch DB Data
        guard let song = await repo.song(id: songId) else { return }
        
        // Update Text Info
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist?.name ?? "Unknown Artist"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album?.title ?? ""
        
        // Push Text Update Immediately (Before waiting for image)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Now try to fetch the image
        if let coverId = song.album?.coverArtId,
           let url = client.coverArtURL(id: coverId, size: 600) {
            
            if let data = try? await client.downloadData(from: url),
               let image = UIImage(data: data) {
                
                let art = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = art
                
                // Push Image Update
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    private func updatePlaybackRate() {
        // Keep lock screen in sync with play/pause state
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.currentItem?.duration.seconds
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Remote Controls
    
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
    
    // MARK: - Observers
    
    private func setupObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updateProgress(time: time)
            }
        }
    }
    
    private func updateProgress(time: CMTime) {
        guard let item = player.currentItem else { return }
        let dur = item.duration.seconds
        if dur.isFinite && dur > 0 {
            self.progress = time.seconds / dur
            self.duration = dur
        }
    }
}

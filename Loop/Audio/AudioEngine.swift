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
    
    // MARK: - State
    var isPlaying: Bool = false
    var currentSongId: String?
    var progress: Double = 0.0
    var duration: Double = 0.0
    
    // MARK: - Dependencies
    private let provider: AssetProvider
    private let stateStore: PlaybackPersistence
    private let repo: MusicRepository
    private let client: NavidromeClient
    
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
        
        // ✅ FIXED: Use modern async API for duration
        // 2. Get initial duration asynchronously
        Task {
            let durationValue = await getDuration()
            
            self.nowPlayingInfo = [
                MPMediaItemPropertyTitle: "Loading...",
                MPMediaItemPropertyArtist: "Unknown Artist",
                MPMediaItemPropertyAlbumTitle: "",
                MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : 180.0,
                MPNowPlayingInfoPropertyPlaybackRate: 0.0,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0
            ]
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            print("✅ Initial metadata set: \(nowPlayingInfo.keys.count) keys")
            print("   Title: \(nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "nil")")
            print("   Duration: \(nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double ?? -1)")
            
            // ✅ NEW: Verify what the system actually has
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let systemInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
                print("🔍 System Now Playing Info after 0.1s: \(systemInfo?.keys.count ?? 0) keys")
                if let title = systemInfo?[MPMediaItemPropertyTitle] as? String {
                    print("   System Title: \(title)")
                }
            }
            
            // 4. Start playback
            play()
            
            // 5. Fetch rich metadata
            Task {
                await loadMetadata(for: currentId)
            }
        }
    }
    
    // ✅ NEW: Helper to get duration using modern API
    private func getDuration() async -> Double {
        guard let item = player.currentItem else { return 180.0 }
        
        do {
            // Modern API: load specific properties
            let duration = try await item.asset.load(.duration)
            let seconds = duration.seconds
            return seconds.isFinite && seconds > 0 ? seconds : 180.0
        } catch {
            print("⚠️ Failed to load duration: \(error)")
            return 180.0 // Fallback
        }
    }

    func play() {
        player.play()
        isPlaying = true
        
        // Only update playback rate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        print("▶️ Now playing with \(nowPlayingInfo.keys.count) metadata keys")
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
        
        // Update duration from DB if available
        if song.duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
        }
        
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
        // Guard against empty metadata
        guard !nowPlayingInfo.isEmpty else { return }
        
        // Keep lock screen in sync with play/pause state
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        
        // ✅ FIXED: Use modern API for duration
        Task {
            if let item = player.currentItem {
                do {
                    let duration = try await item.asset.load(.duration)
                    if duration.seconds.isFinite && duration.seconds > 0 {
                        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration.seconds
                    }
                } catch {
                    // Silently fail - we already have a fallback duration
                }
            }
        }
        
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
        
        // ✅ Use cached duration from nowPlayingInfo instead of deprecated API
        if let dur = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double,
           dur > 0 {
            self.progress = time.seconds / dur
            self.duration = dur
        }
    }
}

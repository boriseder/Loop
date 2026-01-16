//
//  DownloadManager.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import AVFoundation
import Observation
import OSLog

@Observable
final class DownloadManager: AssetProvider {
    
    // MARK: - State
    var activeDownloads: Set<String> = []
    
    // MARK: - Dependencies
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.loopapp", category: "DownloadManager")
    
    // MARK: - Paths
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var downloadsDirectory: URL {
        documentsDirectory.appendingPathComponent("LoopDownloads", conformingTo: .directory)
    }
    
    init(client: NavidromeClient) {
        self.client = client
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Actions
    
    func download(song: Song) async {
        guard !isPinned(songId: song.id) else { return }
        
        _ = await MainActor.run { activeDownloads.insert(song.id) }
        defer { Task { @MainActor in activeDownloads.remove(song.id) } }
        
        logger.info("⬇️ Starting download for: \(song.title)")
        
        do {
            // 1. Get Stream URL (nonisolated, no await needed)
            guard let remoteURL = client.streamURL(for: song.id) else {
                throw URLError(.badURL)
            }
            
            // 2. Download Data (async call to actor)
            let data = try await client.downloadData(from: remoteURL)
            
            // 3. Save to Disk
            guard let localURL = localFileURL(for: song.id) else { return }
            try data.write(to: localURL)
            
            logger.info("✅ Download complete: \(song.title)")
            
            // 4. Optionally download Cover Art
            if let coverId = song.album?.coverArtId {
                await downloadCover(coverId: coverId)
            }
            
        } catch {
            logger.error("❌ Download failed for \(song.title): \(error)")
        }
    }
    
    private func downloadCover(coverId: String) async {
        // ✅ FIX: coverArtURL is nonisolated, no await needed
        guard let url = client.coverArtURL(id: coverId, size: 600) else { return }
        guard let dest = localCoverURL(for: coverId) else { return }
        
        if fileManager.fileExists(atPath: dest.path(percentEncoded: false)) { return }
        
        do {
            let data = try await client.downloadData(from: url)
            try data.write(to: dest)
        } catch {
            logger.warning("Failed to download cover \(coverId)")
        }
    }
    
    // MARK: - AssetProvider Conformance
    
    func asset(for songId: String) async -> AVAsset? {
        // 1. Check disk
        if let localURL = localFileURL(for: songId),
           fileManager.fileExists(atPath: localURL.path(percentEncoded: false)) {
            // Use AVURLAsset for iOS 18+ compliance
            return AVURLAsset(url: localURL)
        }
        
        // 2. Fallback to Stream
        // ✅ FIX: streamURL is nonisolated, no await needed
        guard let url = client.streamURL(for: songId) else { return nil }
        return AVURLAsset(url: url)
    }
    
    // MARK: - Helpers
    
    func localFileURL(for songId: String) -> URL? {
        let filename = "\(songId).m4a"
        return downloadsDirectory.appendingPathComponent(filename)
    }
    
    func localCoverURL(for coverId: String) -> URL? {
        let filename = "cover_\(coverId).jpg"
        return downloadsDirectory.appendingPathComponent(filename)
    }
    
    func isPinned(songId: String) -> Bool {
        guard let url = localFileURL(for: songId) else { return false }
        return fileManager.fileExists(atPath: url.path(percentEncoded: false))
    }
}

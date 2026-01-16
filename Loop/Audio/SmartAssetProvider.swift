//
//  SmartAssetProvider.swift
//  Loop
//
//  Fixed: Removed unnecessary 'try' and handled optional URL
//

import Foundation
import AVFoundation
import OSLog

final class SmartAssetProvider: AssetProvider {
    private let client: NavidromeClient
    private let downloadManager: DownloadManager
    private let logger = Logger(subsystem: "com.loopapp", category: "AssetProvider")
    
    init(client: NavidromeClient, downloadManager: DownloadManager) {
        self.client = client
        self.downloadManager = downloadManager
    }
    
    func asset(for songId: String) async -> AVAsset? {
        // 1. Check Offline File
        if let localURL = downloadManager.localFileURL(for: songId),
           FileManager.default.fileExists(atPath: localURL.path) {
            logger.info("🎧 Playing from local file: \(songId)")
            return AVURLAsset(url: localURL)
        }
        
        // 2. Fallback to Network Stream
        // ✅ FIX: Removed 'try', added 'await', handled optional URL
        if let streamURL = await client.streamURL(for: songId) {
            logger.info("📡 Streaming: \(songId)")
            return AVURLAsset(url: streamURL)
        }
        
        logger.error("❌ Failed to get stream URL for \(songId)")
        return nil
    }
}

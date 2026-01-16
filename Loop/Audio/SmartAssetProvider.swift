//
//  SmartAssetProvider.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import AVFoundation

final class SmartAssetProvider: AssetProvider {
    private let client: NavidromeClient
    private let downloadManager: DownloadManager
    
    init(client: NavidromeClient, downloadManager: DownloadManager) {
        self.client = client
        self.downloadManager = downloadManager
    }
    
    func asset(for songId: String) async -> AVAsset? {
        // 1. Check Offline File
        if let localURL = downloadManager.localFileURL(for: songId),
           FileManager.default.fileExists(atPath: localURL.path) {
            print("🎧 Playing from local file: \(songId)")
            return AVURLAsset(url: localURL)
        }
        
        // 2. Fallback to Network Stream
        if let streamURL = client.streamURL(for: songId) {
            print("📡 Streaming: \(songId)")
            return AVURLAsset(url: streamURL)
        }
        
        return nil
    }
    
    func load(_ property: String) async throws -> Any? {
        return nil // Not used directly
    }
}

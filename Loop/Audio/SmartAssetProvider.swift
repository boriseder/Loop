//
//  SmartAssetProvider.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import AVFoundation

/// A smart provider that decides whether to serve a local file or a remote stream.
/// It wraps the DownloadManager to keep logic clean.
final class SmartAssetProvider: AssetProvider {
    
    private let downloadManager: DownloadManager
    private let client: NavidromeClient
    
    init(downloadManager: DownloadManager, client: NavidromeClient) {
        self.downloadManager = downloadManager
        self.client = client
    }
    
    // MARK: - AssetProvider Conformance
    
    func asset(for songId: String) -> AVAsset? {
        // 1. Check Local File (Offline)
        // ✅ FIX: Now calling the method we added to DownloadManager above
        if let localURL = downloadManager.localFileURL(for: songId),
           FileManager.default.fileExists(atPath: localURL.path(percentEncoded: false)) {
            return AVURLAsset(url: localURL)
        }
        
        // 2. Fallback to Remote Stream (Online)
        guard let remoteURL = client.streamURL(for: songId) else { return nil }
        return AVURLAsset(url: remoteURL)
    }
}

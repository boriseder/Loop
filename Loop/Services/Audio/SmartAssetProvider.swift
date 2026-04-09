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
        print("🎧 AssetProvider: Requesting asset for song \(songId)")
        
        // 1. Check Offline
        let localURL = downloadManager.localFileURL(for: songId)
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("✅ AssetProvider: Found local file at \(localURL.path)")
            return AVURLAsset(url: localURL)
        }
        
        print("⚠️ AssetProvider: No local file, attempting to stream")
        
        // 2. Stream
        if let streamURL = await client.streamURL(for: songId) {
            print("✅ AssetProvider: Got stream URL: \(streamURL.absoluteString)")
            return AVURLAsset(url: streamURL)
        }
        
        print("❌ AssetProvider: Failed to get stream URL")
        return nil
    }
}

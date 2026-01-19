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
        // 1. Check Offline
        let localURL = downloadManager.localFileURL(for: songId)
        if FileManager.default.fileExists(atPath: localURL.path) {
            return AVURLAsset(url: localURL)
        }
        
        // 2. Stream
        if let streamURL = await client.streamURL(for: songId) {
            return AVURLAsset(url: streamURL)
        }
        
        return nil
    }
}

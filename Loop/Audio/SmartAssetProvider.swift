import Foundation
import AVFoundation

final class SmartAssetProvider: AssetProvider {
    private let downloads: DownloadManager
    private let networkMonitor: NetworkMonitor
    private let client: NavidromeClient
    
    // ✅ Keep a strong reference to the delegate
    private let securityDelegate = SecurityDelegate()
    
    init(downloads: DownloadManager, networkMonitor: NetworkMonitor, client: NavidromeClient) {
        self.downloads = downloads
        self.networkMonitor = networkMonitor
        self.client = client
    }
    
    func asset(for songId: String) -> AVURLAsset? {
        // Path A: Local File (Downloads)
        if let localURL = downloads.localFileURL(for: songId),
           FileManager.default.fileExists(atPath: localURL.path) {
            return AVURLAsset(url: localURL)
        }
        
        // Path B: Remote Stream
        guard networkMonitor.isReachable else { return nil }
        
        if let remoteURL = client.streamURL(for: songId) {
            let asset = AVURLAsset(url: remoteURL)
            
            // ✅ FIX: Attach the security delegate to allow self-signed certs
            asset.resourceLoader.setDelegate(securityDelegate, queue: DispatchQueue.global(qos: .userInitiated))
            
            return asset
        }
        return nil
    }
    
    func isAvailable(songId: String) -> Bool {
        if downloads.isPinned(songId) { return true }
        return networkMonitor.isReachable
    }
}

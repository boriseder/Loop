import Foundation
import UIKit
import OSLog

actor CoverArtCache {
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private var memoryCache: [String: UIImage] = [:]
    
    private var cacheDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Covers")
    }
    
    init(client: NavidromeClient) {
        self.client = client
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    func image(for id: String, size: Int) async -> UIImage? {
        // 1. Memory
        if let cached = memoryCache[id] { return cached }
        
        // 2. Disk
        let fileURL = cacheDir.appendingPathComponent("\(id).jpg")
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memoryCache[id] = image
            return image
        }
        
        // 3. Network
        guard let url = await client.coverArtURL(id: id, size: size) else { return nil }
        
        do {
            let data = try await client.downloadData(from: url)
            if let image = UIImage(data: data) {
                try? data.write(to: fileURL)
                memoryCache[id] = image
                return image
            }
        } catch {
            // Silently fail for covers
        }
        return nil
    }
    
    func clearCache() {
        memoryCache.removeAll()
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}

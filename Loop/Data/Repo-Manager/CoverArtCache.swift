//
//  CoverArtCache.swift
//  Loop
//
//  Fixed: Correct handling of Actor calls and Optionals
//

import Foundation
import SwiftUI
import OSLog

@MainActor
final class CoverArtCache {
    
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.loopapp", category: "CoverCache")
    private let memoryCache = NSCache<NSString, UIImage>()
    
    init(client: NavidromeClient) {
        self.client = client
        createCacheDirectory()
    }
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers")
    }
    
    private func createCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getImage(for id: String, size: Int = 300) async -> UIImage? {
        // 1. Check Memory
        if let cached = memoryCache.object(forKey: id as NSString) {
            return cached
        }
        
        // 2. Check Disk
        let fileURL = cacheDirectory.appendingPathComponent("\(id).jpg")
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: id as NSString)
            return image
        }
        
        // 3. Download
        return await downloadCover(id: id, size: size)
    }
    
    @discardableResult
    func downloadCover(id: String, size: Int = 300) async -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(id).jpg")
        
        // ✅ FIX: await actor call, handle optional, remove 'try' from non-throwing call
        guard let remoteURL = await client.coverArtURL(id: id, size: size) else {
            return nil
        }
        
        do {
            let data = try await client.downloadData(from: remoteURL)
            try data.write(to: fileURL)
            
            if let image = UIImage(data: data) {
                memoryCache.setObject(image, forKey: id as NSString)
                return image
            }
        } catch {
            logger.error("Failed to download cover \(id): \(error)")
        }
        
        return nil
    }
}

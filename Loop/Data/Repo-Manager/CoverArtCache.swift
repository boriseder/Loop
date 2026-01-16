//
//  CoverArtCache.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  CoverArtCache.swift
//  Loop
//
//  Manages cover art caching with proper URL caching and disk persistence
//

import Foundation
import UIKit
import OSLog

actor CoverArtCache {
    
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.loopapp", category: "Cache")
    
    // In-memory cache for frequently accessed covers
    private var memoryCache: [String: UIImage] = [:]
    private let maxMemoryCacheSize = 50
    
    private lazy var coversDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("Covers", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    init(client: NavidromeClient) {
        self.client = client
    }
    
    // MARK: - Public Interface
    
    func getImage(for coverArtId: String, size: Int) async -> UIImage? {
        // 1. Check memory cache
        let cacheKey = "\(coverArtId)-\(size)"
        if let cached = memoryCache[cacheKey] {
            return cached
        }
        
        // 2. Check disk cache
        if let diskImage = loadFromDisk(id: coverArtId) {
            cacheInMemory(image: diskImage, key: cacheKey)
            return diskImage
        }
        
        // 3. Download from server
        guard let downloaded = await downloadCover(id: coverArtId, size: size) else {
            return nil
        }
        
        cacheInMemory(image: downloaded, key: cacheKey)
        return downloaded
    }
    
    func downloadCover(id: String, size: Int = 600) async -> UIImage? {
        do {
            let url = try await client.coverArtURL(id: id, size: size)
            let data = try await client.downloadData(from: url)
            
            guard let image = UIImage(data: data) else {
                logger.warning("Failed to decode cover image: \(id)")
                return nil
            }
            
            // Save to disk
            saveToDisk(data: data, id: id)
            
            return image
            
        } catch {
            logger.error("Failed to download cover \(id): \(error.localizedDescription)")
            return nil
        }
    }
    
    func clearCache() async throws {
        memoryCache.removeAll()
        
        let files = try fileManager.contentsOfDirectory(at: coversDirectory, includingPropertiesForKeys: nil)
        for file in files {
            try fileManager.removeItem(at: file)
        }
        
        logger.info("🗑️ Cache cleared")
    }
    
    func getCacheSize() async -> Int64 {
        var totalSize: Int64 = 0
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: coversDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        
        for fileURL in files {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
    
    // MARK: - Private Helpers
    
    private func localFileURL(for id: String) -> URL {
        return coversDirectory.appendingPathComponent("\(id).jpg")
    }
    
    private func loadFromDisk(id: String) -> UIImage? {
        let url = localFileURL(for: id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveToDisk(data: Data, id: String) {
        let url = localFileURL(for: id)
        try? data.write(to: url)
    }
    
    private func cacheInMemory(image: UIImage, key: String) {
        // Simple LRU: if cache is full, remove first item
        if memoryCache.count >= maxMemoryCacheSize {
            memoryCache.removeValue(forKey: memoryCache.keys.first!)
        }
        memoryCache[key] = image
    }
}
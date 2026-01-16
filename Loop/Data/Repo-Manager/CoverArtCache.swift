//
//  CoverArtCache.swift
//  Loop
//
//  FIXED: Added LRU eviction, size limits, proper concurrency
//

import Foundation
import SwiftUI
import OSLog

actor CoverArtCache {
    
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.loopapp", category: "CoverCache")
    
    // Memory cache with size limit
    private var memoryCache: [String: CachedImage] = [:]
    private var accessOrder: [String] = [] // For LRU
    
    // Constants
    private let maxMemoryItems = 100  // ~20MB RAM for 100 300x300 images
    private let maxDiskSizeBytes: Int64 = .max // No limit - offline-first app caches everything
    
    init(client: NavidromeClient) {
        self.client = client
        Task {
            await createCacheDirectory()
            await cleanupOldCacheIfNeeded()
        }
    }
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers")
    }
    
    private func createCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public API
    
    func getImage(for id: String, size: Int) async -> UIImage? {
        // 1. Check Memory (LRU)
        if let cached = memoryCache[id] {
            updateAccessOrder(for: id)
            return cached.image
        }
        
        // 2. Check Disk
        let fileURL = cacheDirectory.appendingPathComponent("\(id).jpg")
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cacheInMemory(id: id, image: image)
            return image
        }
        
        // 3. Download
        return await downloadCover(id: id, size: size)
    }
    
    @discardableResult
    func downloadCover(id: String, size: Int = 300) async -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(id).jpg")
        
        guard let remoteURL = await client.coverArtURL(id: id, size: size) else {
            logger.error("No cover URL for \(id)")
            return nil
        }
        
        do {
            let data = try await client.downloadData(from: remoteURL)
            try data.write(to: fileURL)
            
            if let image = UIImage(data: data) {
                cacheInMemory(id: id, image: image)
                
                // No automatic cleanup for offline-first app
                // User can manually clear cache in settings if needed
                
                return image
            }
        } catch is CancellationError {
            logger.info("Download cancelled for \(id)")
            return nil
        } catch {
            logger.error("Failed to download cover \(id): \(error)")
        }
        
        return nil
    }
    
    func clearCache() async {
        memoryCache.removeAll()
        accessOrder.removeAll()
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try? fileManager.removeItem(at: fileURL)
            }
            logger.info("Cache cleared")
        } catch {
            logger.error("Failed to clear cache: \(error)")
        }
    }
    
    func getCacheSize() async -> Int64 {
        var totalSize: Int64 = 0
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
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
    
    private func cacheInMemory(id: String, image: UIImage) {
        // Evict oldest if at capacity
        if memoryCache.count >= maxMemoryItems {
            evictOldestFromMemory()
        }
        
        memoryCache[id] = CachedImage(image: image, lastAccessed: Date())
        accessOrder.append(id)
    }
    
    private func updateAccessOrder(for id: String) {
        accessOrder.removeAll { $0 == id }
        accessOrder.append(id)
        memoryCache[id]?.lastAccessed = Date()
    }
    
    private func evictOldestFromMemory() {
        guard let oldest = accessOrder.first else { return }
        memoryCache.removeValue(forKey: oldest)
        accessOrder.removeFirst()
    }
    
    private func cleanupOldCacheIfNeeded() async {
        let currentSize = await getCacheSize()
        
        guard currentSize > maxDiskSizeBytes else { return }
        
        logger.warning("Cache size \(currentSize) exceeds limit, cleaning up...")
        
        // Get all files with modification dates
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        // Sort by modification date (oldest first)
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }
        
        // Delete oldest files until under limit
        var deletedSize: Int64 = 0
        let targetDeletion = currentSize - (maxDiskSizeBytes * 8 / 10) // Delete to 80% of limit
        
        for file in sortedFiles {
            guard deletedSize < targetDeletion else { break }
            
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                try? fileManager.removeItem(at: file)
                deletedSize += Int64(size)
            }
        }
        
        logger.info("Cleaned up \(deletedSize) bytes from cache")
    }
}

// MARK: - Supporting Types

private struct CachedImage {
    let image: UIImage
    var lastAccessed: Date
}

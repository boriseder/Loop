//
//  CoverArtCache.swift
//  Loop
//
//  FIXED: Explicit closure types for detached tasks
//

import Foundation
import SwiftUI
import OSLog

actor CoverArtCache {
    
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.loopapp", category: "CoverCache")
    
    // LRU Memory Cache
    private var memoryCache: [String: UIImage] = [:]
    private var accessOrder: [String] = []
    private let maxMemoryItems = 50
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers")
    }
    
    init(client: NavidromeClient) {
        self.client = client
        // Non-blocking directory creation
        Task.detached(priority: .utility) { [weak self] in
            await self?.createCacheDirectory()
        }
    }
    
    private func createCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public API
    
    func getImage(for id: String, size: Int) async -> UIImage? {
        // 1. Fast Path: RAM
        if let cached = memoryCache[id] {
            updateAccessOrder(for: id)
            return cached
        }
        
        let fileURL = cacheDirectory.appendingPathComponent("\(id).jpg")
        
        // 2. Medium Path: Disk (Concurrent)
        // Explicitly typed closure to fix 'nil' compatibility error
        let diskImage = await Task.detached(priority: .userInitiated) { [fileURL] () -> UIImage? in
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                return image
            }
            return nil
        }.value
        
        if let diskImage {
            cacheInMemory(id: id, image: diskImage)
            return diskImage
        }
        
        // 3. Slow Path: Network
        return await downloadCover(id: id, size: size)
    }
    
    @discardableResult
    func downloadCover(id: String, size: Int = 300) async -> UIImage? {
        guard let remoteURL = await client.coverArtURL(id: id, size: size) else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent("\(id).jpg")
        
        do {
            let data = try await client.downloadData(from: remoteURL)
            
            // Write to disk in background
            Task.detached(priority: .utility) { [fileURL, data] in
                try? data.write(to: fileURL)
            }
            
            if let image = UIImage(data: data) {
                cacheInMemory(id: id, image: image)
                return image
            }
        } catch {
            logger.debug("Failed download for \(id): \(error)")
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    
    private func cacheInMemory(id: String, image: UIImage) {
        if memoryCache.count >= maxMemoryItems {
            evictOldestFromMemory()
        }
        memoryCache[id] = image
        accessOrder.append(id)
    }
    
    private func updateAccessOrder(for id: String) {
        if let index = accessOrder.firstIndex(of: id) {
            accessOrder.remove(at: index)
            accessOrder.append(id)
        }
    }
    
    private func evictOldestFromMemory() {
        guard let oldest = accessOrder.first else { return }
        memoryCache.removeValue(forKey: oldest)
        accessOrder.removeFirst()
    }
    
    func clearCache() async {
        memoryCache.removeAll()
        accessOrder.removeAll()
        
        let dir = cacheDirectory
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

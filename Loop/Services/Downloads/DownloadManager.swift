//
//  DownloadManager.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import Observation
import OSLog

@Observable @MainActor
final class DownloadManager {
    
    // MARK: - State
    private(set) var activeDownloads: Set<String> = [] // Track Song IDs or Album IDs being processed
    
    // MARK: - Dependencies
    private let client: NavidromeClient
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.loopapp", category: "Downloads")
    
    init(client: NavidromeClient) {
        self.client = client
        createDirectories()
    }
    
    // MARK: - Paths
    
    private var musicDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Music")
    }
    
    private var coversDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Covers")
    }
    
    private func createDirectories() {
        try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
    }
    
    func localFileURL(for songId: String) -> URL? {
        let path = musicDirectory.appendingPathComponent("\(songId).mp3") // Simplified extension logic
        return path
    }
    
    func localCoverURL(for coverId: String) -> URL {
        return coversDirectory.appendingPathComponent("\(coverId).jpg")
    }
    
    // MARK: - Status Checks
    
    func isPinned(songId: String) -> Bool {
        guard let url = localFileURL(for: songId) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }
    
    func isAlbumFullyDownloaded(songIds: [String]) -> Bool {
        guard !songIds.isEmpty else { return false }
        return songIds.allSatisfy { isPinned(songId: $0) }
    }
    
    func isDownloading(albumId: String) -> Bool {
        return activeDownloads.contains(albumId)
    }
    
    // MARK: - Actions
    
    func download(song: Loop.Song) async {
        guard let url = localFileURL(for: song.id) else { return }
        
        // 1. Skip if exists
        if fileManager.fileExists(atPath: url.path) {
            // Even if song exists, ensure cover exists
            if let coverId = song.album?.coverArtId {
                await downloadCover(coverId: coverId)
            }
            return
        }
        
        // 2. Mark as Downloading
        activeDownloads.insert(song.id) // Track individual song
        defer { activeDownloads.remove(song.id) }
        
        // 3. Download Audio
        logger.info("⬇️ Downloading song: \(song.title)")
        do {
            if let streamURL = client.streamURL(for: song.id),
               let data = try? await client.downloadData(from: streamURL) {
                try data.write(to: url)
                logger.info("✅ Saved song: \(song.title)")
            }
        } catch {
            logger.error("❌ Failed to download song: \(error)")
        }
        
        // 4. Download Cover Art (Critical for Offline)
        if let coverId = song.album?.coverArtId {
            await downloadCover(coverId: coverId)
        }
    }
    
    func downloadCover(coverId: String) async {
        let url = localCoverURL(for: coverId)
        if fileManager.fileExists(atPath: url.path) { return }
        
        logger.info("🖼️ Downloading cover: \(coverId)")
        
        // Attempt download
        if let remoteURL = client.coverArtURL(id: coverId, size: 600),
           let data = try? await client.downloadData(from: remoteURL) {
            try? data.write(to: url)
            logger.info("✅ Saved cover art")
        }
    }
    
    func deleteDownload(song: Loop.Song) {
        if let url = localFileURL(for: song.id) {
            try? fileManager.removeItem(at: url)
            logger.info("🗑️ Deleted song: \(song.title)")
        }
    }
    
    // Helper for Album Download
    func downloadAlbum(albumId: String, songs: [Loop.Song]) async {
        activeDownloads.insert(albumId) // Track Album Level
        
        for song in songs {
            await download(song: song)
        }
        
        activeDownloads.remove(albumId)
    }
}

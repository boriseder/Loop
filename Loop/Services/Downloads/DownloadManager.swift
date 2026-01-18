//
//  DownloadManager.swift
//  Loop
//
//  FIXED: Decoupled Storage logic (Thread-Safe) from Manager logic
//

import Foundation
import Observation
import OSLog
import Network

// MARK: - Storage Strategy (Thread Safe)
// MARK: - Storage Strategy (Thread Safe)
// This struct handles all File I/O paths and checks. It is Sendable and Non-Isolated.
struct DownloadStorage: Sendable {
    // ❌ REMOVED: private let fileManager = FileManager.default (caused isolation issues)
    
    // ✅ FIX: Explicit nonisolated init
    nonisolated init() {}
    
    // ✅ FIX: Explicit nonisolated computed property
    nonisolated var musicDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music")
    }
    
    // ✅ FIX: Explicit nonisolated method using FileManager.default directly
    nonisolated func createDirectories() {
        try? FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
    }
    
    // ✅ FIX: Explicit nonisolated method
    nonisolated func localFileURL(for songId: String) -> URL {
        musicDirectory.appendingPathComponent("\(songId).mp3")
    }
    
    // ✅ FIX: Explicit nonisolated method using FileManager.default directly
    nonisolated func isSongDownloaded(id: String) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: id).path)
    }
    
    // ✅ FIX: Explicit nonisolated method
    nonisolated func isAlbumFullyDownloaded(songIds: [String]) -> Bool {
        guard !songIds.isEmpty else { return false }
        return songIds.allSatisfy { isSongDownloaded(id: $0) }
    }
    
    // ✅ FIX: Explicit nonisolated method using FileManager.default directly
    nonisolated func getTotalDownloadSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: musicDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        return files.reduce(0) { result, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return result + Int64(size)
        }
    }
}

// MARK: - Manager (Stateful)

@Observable @MainActor
final class DownloadManager {
    
    private(set) var activeDownloads: Set<String> = []
    
    // ✅ Public Accessor for Thread-Safe Storage Logic
    nonisolated let storage = DownloadStorage()
    
    private let client: NavidromeClient
    private let logger = Logger(subsystem: "com.loopapp", category: "Downloads")
    private let networkMonitor = NWPathMonitor()
    private var isOnWiFi = false
    
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    
    init(client: NavidromeClient) {
        self.client = client
        storage.createDirectories()
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Delegates to Storage (Non-Isolated)
    
    nonisolated func isAlbumFullyDownloaded(songIds: [String]) -> Bool {
        storage.isAlbumFullyDownloaded(songIds: songIds)
    }
    
    nonisolated func isPinned(songId: String) -> Bool {
        storage.isSongDownloaded(id: songId)
    }
    
    nonisolated func localFileURL(for songId: String) -> URL? {
        storage.localFileURL(for: songId)
    }
    
    // MARK: - Main Actor State
    
    func isDownloading(albumId: String) -> Bool {
        activeDownloads.contains(albumId)
    }
    
    // MARK: - Actions
    
    func downloadSong(id: String, path: String, coverId: String?) async {
        let url = storage.localFileURL(for: id)
        
        if FileManager.default.fileExists(atPath: url.path) { return }
        
        guard isOnWiFi else {
            logger.warning("Download blocked: not on WiFi")
            return
        }
        
        activeDownloads.insert(id)
        defer { activeDownloads.remove(id) }
        
        let task = Task {
            do {
                guard let streamURL = await client.streamURL(for: id) else { throw DownloadError.invalidURL }
                let data = try await client.downloadData(from: streamURL)
                try data.write(to: url)
                logger.info("✅ Saved: \(id)")
            } catch {
                logger.error("Download failed: \(error)")
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        downloadTasks[id] = task
        await task.value
        downloadTasks.removeValue(forKey: id)
    }
    
    func downloadAlbum(albumId: String, songs: [(id: String, path: String, coverId: String?)]) async {
        activeDownloads.insert(albumId)
        defer { activeDownloads.remove(albumId) }
        
        await withTaskGroup(of: Void.self) { group in
            let maxConcurrent = isOnWiFi ? 3 : 1
            var active = 0
            for song in songs {
                if active >= maxConcurrent { await group.next(); active -= 1 }
                group.addTask { await self.downloadSong(id: song.id, path: song.path, coverId: song.coverId) }
                active += 1
            }
        }
    }
    
    func deleteDownload(songId: String) {
        downloadTasks[songId]?.cancel()
        let url = storage.localFileURL(for: songId)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnWiFi = path.usesInterfaceType(.wifi)
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}

enum DownloadError: LocalizedError {
    case invalidURL
}

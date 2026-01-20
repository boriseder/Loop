import Foundation
import Observation
import OSLog

// MARK: - Download Progress
struct DownloadProgress: Sendable {
    let songId: String
    let bytesDownloaded: Int64
    let totalBytes: Int64
    
    var percentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }
}

// MARK: - Download Manager (MainActor ONLY for @Observable state)
@Observable @MainActor
final class DownloadManager {
    // MARK: - Published State
    private(set) var activeDownloads: [String: DownloadProgress] = [:]
    
    // MARK: - Private
    private let client: NavidromeClient
    private let logger = Logger(subsystem: "com.loopapp", category: "Downloads")
    private let fileManager = FileManager.default
    
    // Task tracking
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    
    // Queue to limit concurrent downloads
    private let maxConcurrentDownloads = 3
    private var activeCount = 0
    
    init(client: NavidromeClient) {
        self.client = client
        createMusicDirectory()
    }
    
    // MARK: - Public API
    
    func isDownloaded(songId: String) -> Bool {
        fileManager.fileExists(atPath: localFileURL(for: songId).path)
    }
    
    func localFileURL(for songId: String) -> URL {
        musicDirectory.appendingPathComponent("\(songId).mp3")
    }
    
    func downloadSong(song: SongDTO) {
        let id = song.id
        
        // Check if already downloaded or downloading
        guard !isDownloaded(songId: id),
              downloadTasks[id] == nil else { return }
        
        // Create download task - FIX: Explicitly handle the optional return
        let task = Task.detached(priority: .utility) { [weak self] in
            await self?.performDownload(song: song)
            return () // Explicitly return Void
        }
        
        downloadTasks[id] = task
    }
    
    func cancelDownload(songId: String) {
        downloadTasks[songId]?.cancel()
        downloadTasks.removeValue(forKey: songId)
        activeDownloads.removeValue(forKey: songId)
    }
    
    func deleteDownload(songId: String) {
        cancelDownload(songId: songId)
        try? fileManager.removeItem(at: localFileURL(for: songId))
    }
    
    func deleteAlbumDownloads(songIds: [String]) {
        for id in songIds {
            deleteDownload(songId: id)
        }
    }
    
    // MARK: - Private Implementation
    
    private var musicDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music")
    }
    
    private func createMusicDirectory() {
        try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
    }
    
    private func performDownload(song: SongDTO) async {
        let id = song.id
        
        // Update state: download started
        await MainActor.run {
            activeDownloads[id] = DownloadProgress(songId: id, bytesDownloaded: 0, totalBytes: 0)
        }
        
        defer {
            Task { @MainActor in
                activeDownloads.removeValue(forKey: id)
                downloadTasks.removeValue(forKey: id)
            }
        }
        
        do {
            guard let url = await client.streamURL(for: id) else {
                throw DownloadError.invalidURL
            }
            
            // Check available disk space
            guard hasEnoughDiskSpace() else {
                throw DownloadError.insufficientStorage
            }
            
            // Download with progress tracking
            let (localURL, response) = try await URLSession.shared.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw DownloadError.networkError
            }
            
            // Move to final location
            let destination = localFileURL(for: id)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: localURL, to: destination)
            
            logger.info("Downloaded: \(song.title)")
            
        } catch {
            logger.error("Download failed [\(id)]: \(error.localizedDescription)")
        }
    }
    
    private func hasEnoughDiskSpace(required: Int64 = 100_000_000) -> Bool {
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: musicDirectory.path),
              let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            return true // Optimistic if we can't check
        }
        return freeSpace > required
    }
}

// MARK: - Errors
enum DownloadError: LocalizedError {
    case invalidURL
    case insufficientStorage
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid download URL"
        case .insufficientStorage: return "Not enough storage space"
        case .networkError: return "Network error occurred"
        }
    }
}

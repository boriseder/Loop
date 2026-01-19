import Foundation
import Observation
import OSLog

@Observable @MainActor
final class DownloadManager {
    var activeDownloads: Set<String> = [] // IDs of songs being downloaded
    
    private let client: NavidromeClient
    private let logger = Logger(subsystem: "com.loopapp", category: "Downloads")
    
    init(client: NavidromeClient) {
        self.client = client
        createMusicDirectory()
    }
    
    private var musicDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Music")
    }
    
    private func createMusicDirectory() {
        try? FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
    }
    
    func localFileURL(for songId: String) -> URL {
        musicDirectory.appendingPathComponent("\(songId).mp3")
    }
    
    func isDownloaded(songId: String) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: songId).path)
    }
    
    func downloadSong(song: SongDTO) async {
        let id = song.id
        guard !isDownloaded(songId: id) else { return }
        
        activeDownloads.insert(id)
        defer { activeDownloads.remove(id) }
        
        do {
            guard let url = await client.streamURL(for: id) else { return }
            let data = try await client.downloadData(from: url)
            try data.write(to: localFileURL(for: id))
            logger.info("Downloaded song: \(song.title)")
        } catch {
            logger.error("Failed to download \(id): \(error)")
        }
    }
    
    func deleteDownload(songId: String) {
        try? FileManager.default.removeItem(at: localFileURL(for: songId))
    }
    
    func deleteAlbumDownloads(songIds: [String]) {
        for id in songIds {
            deleteDownload(songId: id)
        }
    }
}

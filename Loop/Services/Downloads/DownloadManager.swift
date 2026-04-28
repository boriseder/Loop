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

// MARK: - URLSession factory (outside the @Observable class to avoid macro conflicts)
private func makeBackgroundSession(delegate: URLSessionDownloadDelegate) -> URLSession {
    let config = URLSessionConfiguration.background(
        withIdentifier: "at.amtabor.loop.downloads"
    )
    config.isDiscretionary = false          // Download now, not at the system's leisure
    config.sessionSendsLaunchEvents = true  // Wake the app when downloads finish
    return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
}

// MARK: - Download Manager
@Observable @MainActor
final class DownloadManager: NSObject {

    // MARK: - Observable State
    private(set) var activeDownloads: [String: DownloadProgress] = [:]

    // MARK: - Private
    private let logger = Logger(subsystem: "at.amtabor.loop", category: "Downloads")
    private let fileManager = FileManager.default

    /// Stable background URLSession. Stored as a plain let so @Observable is happy.
    /// Created via the free function above so self is fully initialised before
    /// being passed as delegate.
    private var session: URLSession!

    /// Maps URLSessionTask.taskIdentifier → songId so the delegate can route events.
    private var taskIndex: [Int: String] = [:]

    /// Completion handler vended by the system when the app is woken for a background session.
    /// Must be called once all delegate events have been delivered (see LoopApp).
    var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Init
    override init() {
        super.init()
        // self is fully initialised here so we can safely pass it as delegate
        session = makeBackgroundSession(delegate: self)
        createMusicDirectory()
        reconnectPendingTasks()
    }

    // MARK: - Public API

    func isDownloaded(songId: String) -> Bool {
        fileManager.fileExists(atPath: localFileURL(for: songId).path)
    }

    func localFileURL(for songId: String) -> URL {
        musicDirectory.appendingPathComponent("\(songId).mp3")
    }

    /// Enqueue a song for download. Safe to call if already downloaded or in-flight.
    func downloadSong(song: SongDTO, streamURL: URL) {
        let id = song.id

        guard !isDownloaded(songId: id) else {
            logger.debug("Already downloaded: \(song.title)")
            return
        }
        guard activeDownloads[id] == nil else {
            logger.debug("Already in flight: \(song.title)")
            return
        }

        logger.info("Enqueuing download: \(song.title)")

        let task = session.downloadTask(with: streamURL)
        task.taskDescription = id           // Survives suspend/resume cycles
        taskIndex[task.taskIdentifier] = id
        activeDownloads[id] = DownloadProgress(songId: id, bytesDownloaded: 0, totalBytes: 0)
        task.resume()
    }

    func cancelDownload(songId: String) {
        guard let taskId = taskIndex.first(where: { $0.value == songId })?.key else { return }
        session.getAllTasks { tasks in
            tasks.first { $0.taskIdentifier == taskId }?.cancel()
        }
        taskIndex.removeValue(forKey: taskId)
        Task { @MainActor in
            self.activeDownloads.removeValue(forKey: songId)
        }
    }

    func deleteDownload(songId: String) {
        cancelDownload(songId: songId)
        try? fileManager.removeItem(at: localFileURL(for: songId))
    }

    func deleteAlbumDownloads(songIds: [String]) {
        songIds.forEach { deleteDownload(songId: $0) }
    }

    // MARK: - Directory

    private var musicDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music")
    }

    private func createMusicDirectory() {
        try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Reconnect tasks in-flight from a previous launch

    private func reconnectPendingTasks() {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            for task in tasks {
                guard let songId = task.taskDescription else { continue }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.taskIndex[task.taskIdentifier] = songId
                    if self.activeDownloads[songId] == nil {
                        self.activeDownloads[songId] = DownloadProgress(
                            songId: songId, bytesDownloaded: 0, totalBytes: 0
                        )
                    }
                    self.logger.info("Reconnected in-flight download: \(songId)")
                }
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let songId = downloadTask.taskDescription else { return }
        let progress = DownloadProgress(
            songId: songId,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
        Task { @MainActor [weak self] in
            self?.activeDownloads[songId] = progress
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let songId = downloadTask.taskDescription else { return }

        // location is a temp file deleted after this method returns — move it synchronously.
        let fm = FileManager.default
        let destination = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music/\(songId).mp3")

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: location, to: destination)
        } catch {
            // Log via a detached task so we don't capture self in a nonisolated context
            Task.detached {
                Logger(subsystem: "at.amtabor.loop", category: "Downloads")
                    .error("Failed to move download for \(songId): \(error.localizedDescription)")
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activeDownloads.removeValue(forKey: songId)
            self.taskIndex.removeValue(forKey: downloadTask.taskIdentifier)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, let songId = task.taskDescription else { return }
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }

        Task.detached {
            Logger(subsystem: "at.amtabor.loop", category: "Downloads")
                .error("Download failed for \(songId): \(error.localizedDescription)")
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activeDownloads.removeValue(forKey: songId)
            self.taskIndex.removeValue(forKey: task.taskIdentifier)
        }
    }
}

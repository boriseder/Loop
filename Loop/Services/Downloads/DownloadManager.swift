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
final class DownloadManager: NSObject {
    
    // MARK: - State
    var activeDownloads: [String: Double] = [:] // SongID : Progress
    
    // MARK: - Dependencies
    private let client: NavidromeClient
    private let logger = Logger(subsystem: "com.loopapp", category: "DownloadManager")
    
    // MARK: - Session
    private var session: URLSession!
    private var backgroundCompletionHandler: (() -> Void)?
    
    init(client: NavidromeClient) {
        self.client = client
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.loop.background.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func download(song: Song) {
        if isPinned(song.id) { return }
        
        guard let url = client.streamURL(for: song.id) else { return }
        
        let task = session.downloadTask(with: url)
        task.taskDescription = song.id
        task.resume()
        
        activeDownloads[song.id] = 0.0
    }
    
    func isPinned(_ songId: String) -> Bool {
        guard let url = localFileURL(for: songId) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func localFileURL(for songId: String) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = documents.appendingPathComponent("Downloads", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("\(songId).mp3")
    }
    
    func restoreSession(id: String, completion: @escaping () -> Void) {
        self.backgroundCompletionHandler = completion
    }
}

// MARK: - URLSessionDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let songId = downloadTask.taskDescription else { return }
        
        Task { @MainActor in
            guard let destination = self.localFileURL(for: songId) else { return }
            try? FileManager.default.removeItem(at: destination) // overwrite
            try? FileManager.default.moveItem(at: location, to: destination)
            self.activeDownloads.removeValue(forKey: songId)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let songId = downloadTask.taskDescription else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            self.activeDownloads[songId] = progress
        }
    }
    
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

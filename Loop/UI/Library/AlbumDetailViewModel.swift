//
//  AlbumDetailViewModel.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation

@Observable @MainActor
final class AlbumDetailViewModel {
    
    enum DownloadState {
        case idle
        case downloading
        case downloaded
    }
    
    var album: Loop.Album?
    var songs: [Loop.Song] = []
    var isLoading = false
    var downloadState: DownloadState = .idle
    
    private let albumId: String
    private let repo: MusicRepository
    private let downloads: DownloadManager
    private let player: AudioEngine
    
    init(albumId: String, repo: MusicRepository, downloads: DownloadManager, player: AudioEngine) {
        self.albumId = albumId
        self.repo = repo
        self.downloads = downloads
        self.player = player
    }
    
    func load() async {
        self.album = repo.getLocalAlbum(id: albumId)
        self.songs = repo.getLocalSongs(for: albumId)
        updateDownloadState()
        
        isLoading = true
        await repo.syncAlbumDetails(albumId: albumId)
        
        self.songs = repo.getLocalSongs(for: albumId)
        isLoading = false
        updateDownloadState()
    }
    
    func toggleDownload() {
        switch downloadState {
        case .downloaded:
            // Delete logic (optional, for now we just keep it simple)
            for song in songs { downloads.deleteDownload(song: song) }
            updateDownloadState()
            
        case .idle:
            downloadState = .downloading
            Task {
                await downloads.downloadAlbum(albumId: albumId, songs: songs)
                updateDownloadState()
            }
            
        case .downloading:
            break // Already working
        }
    }
    
    func updateDownloadState() {
        if downloads.isDownloading(albumId: albumId) {
            downloadState = .downloading
        } else if !songs.isEmpty && downloads.isAlbumFullyDownloaded(songIds: songs.map(\.id)) {
            downloadState = .downloaded
        } else {
            downloadState = .idle
        }
    }
    
    func play(song: Loop.Song) {
        let songIds = songs.map { $0.id }
        Task {
            await player.setupPlayer(with: song.id, queue: songIds)
        }
    }
}

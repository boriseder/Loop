//
//  AlbumDetailViewModel.swift
//  Loop
//
//  FIXED: Uses environment objects, async operations
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
    
    var album: AlbumDTO?
    var songs: [SongDTO] = []
    var isLoading = false
    var downloadState: DownloadState = .idle
    
    private let albumId: String
    private let music: MusicEnvironment
    private let playback: PlaybackEnvironment
    private let downloads: DownloadEnvironment
    
    init(albumId: String, music: MusicEnvironment, playback: PlaybackEnvironment, downloads: DownloadEnvironment) {
        self.albumId = albumId
        self.music = music
        self.playback = playback
        self.downloads = downloads
    }
    
    func load() async {
        do {
            // Load from local DB first
            self.album = try await music.getAlbum(id: albumId)
            self.songs = try await music.getSongs(for: albumId)
            updateDownloadState()
            
            // Sync from server
            isLoading = true
            try await music.syncAlbumDetails(albumId: albumId)
            
            // Reload after sync
            self.album = try await music.getAlbum(id: albumId)
            self.songs = try await music.getSongs(for: albumId)
            isLoading = false
            updateDownloadState()
            
        } catch {
            isLoading = false
            print("Error loading album: \(error)")
        }
    }
    
    func toggleDownload() async {
        switch downloadState {
        case .downloaded:
            // Delete all songs
            for song in songs {
                downloads.deleteDownload(songId: song.id)
            }
            updateDownloadState()
            
        case .idle:
            downloadState = .downloading
            await downloads.downloadAlbum(albumId: albumId, songs: songs)
            updateDownloadState()
            
        case .downloading:
            break
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
    
    func play(song: SongDTO) async {
        let songIds = songs.map { $0.id }
        await playback.setupPlayer(with: song.id, queue: songIds)
    }
}

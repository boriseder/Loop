//
//  AppContainer.swift
//  Loop
//
//  FIXED: Exposed session restoration to AuthEnvironment
//

import Foundation
import SwiftUI
import Observation

// MARK: - Main Container

final class AppContainer {
    
    private let client: NavidromeClient
    private let db: MusicDatabase
    private let repo: MusicRepository
    
    let auth: AuthEnvironment
    let music: MusicEnvironment
    let playback: PlaybackEnvironment
    let downloads: DownloadEnvironment
    
    var router = Router()
    
    init() {
        let client = NavidromeClient()
        let db = MusicDatabase()
        let repo = MusicRepository(db: db)
        
        let coverCache = CoverArtCache(client: client)
        let downloadManager = DownloadManager(client: client)
        let syncManager = SyncManager(repo: repo, client: client, cache: coverCache)
        let authService = AuthenticationService(client: client, syncManager: syncManager)
        
        let assetProvider = SmartAssetProvider(client: client, downloadManager: downloadManager)
        let audioEngine = AudioEngine(
            provider: assetProvider,
            stateStore: UserDefaultsPersistence(),
            repo: repo,
            coverCache: coverCache
        )
        
        self.client = client
        self.db = db
        self.repo = repo
        
        self.auth = AuthEnvironment(service: authService)
        self.music = MusicEnvironment(repo: repo, sync: syncManager, coverCache: coverCache, downloads: downloadManager)
        self.playback = PlaybackEnvironment(engine: audioEngine)
        self.downloads = DownloadEnvironment(manager: downloadManager)
    }
}

// MARK: - Focused Environment Objects

@Observable @MainActor
final class AuthEnvironment {
    private let service: AuthenticationService
    
    var isAuthenticated: Bool { service.isAuthenticated }
    var authError: String? { service.authError }
    
    init(service: AuthenticationService) {
        self.service = service
    }
    
    // ✅ NEW: Delegate call to service
    func restoreSession() async {
        await service.restoreSession()
    }
    
    func login(credentials: Credentials) async {
        await service.login(credentials: credentials)
    }
    
    func logout() async {
        await service.logout()
    }
}

// (MusicEnvironment, PlaybackEnvironment, DownloadEnvironment remain unchanged)
@Observable @MainActor
final class MusicEnvironment {
    private let repo: MusicRepository
    private let sync: SyncManager
    private let coverCache: CoverArtCache
    private let downloadManager: DownloadManager
    
    private(set) var syncProgress: SyncProgress = SyncProgress(phase: .idle)
    private(set) var isSyncing = false
    
    var downloadedAlbumIds: Set<String> = []
    var downloadedArtistIds: Set<String> = []
    var downloadedGenres: Set<String> = []
    
    init(repo: MusicRepository, sync: SyncManager, coverCache: CoverArtCache, downloads: DownloadManager) {
        self.repo = repo
        self.sync = sync
        self.coverCache = coverCache
        self.downloadManager = downloads
        
        Task { @MainActor in
            await sync.setProgressCallback { [weak self] progress in
                self?.syncProgress = progress
                self?.isSyncing = progress.isActive
            }
        }
    }
    
    func updateDownloadedState() async {
        let storage = downloadManager.storage
        let repo = self.repo
        let state = await Task.detached(priority: .utility) {
            var dAlbums = Set<String>()
            var dArtists = Set<String>()
            var dGenres = Set<String>()
            do {
                let allAlbums = try await repo.getAlbums(offset: 0, limit: 10000)
                for album in allAlbums {
                    if let songs = try? await repo.getSongs(for: album.id) {
                        let songIds = songs.map { $0.id }
                        if !songIds.isEmpty && storage.isAlbumFullyDownloaded(songIds: songIds) {
                            dAlbums.insert(album.id)
                            dArtists.insert(album.artistId)
                            if let g = album.genre { dGenres.insert(g) }
                        }
                    }
                }
            } catch { print("Error calculating global download state: \(error)") }
            return (dAlbums, dArtists, dGenres)
        }.value
        self.downloadedAlbumIds = state.0
        self.downloadedArtistIds = state.1
        self.downloadedGenres = state.2
    }
    
    func getAlbums(offset: Int = 0, limit: Int = 100) async throws -> [AlbumDTO] { try await repo.getAlbums(offset: offset, limit: limit) }
    func getArtists(offset: Int = 0, limit: Int = 100) async throws -> [ArtistDTO] { try await repo.getArtists(offset: offset, limit: limit) }
    func getGenres() async throws -> [GenreDTO] { try await repo.getGenres() }
    func getAlbum(id: String) async throws -> [AlbumDTO]? { return nil } // Correction: Repo signature returns AlbumDTO?
    func getAlbum(id: String) async throws -> AlbumDTO? { try await repo.getAlbum(id: id) }
    func getSongs(for albumId: String) async throws -> [SongDTO] { try await repo.getSongs(for: albumId) }
    func getArtist(id: String) async throws -> ArtistDTO? { try await repo.getArtist(id: id) }
    func getAlbums(forArtist artistId: String) async throws -> [AlbumDTO] { try await repo.getAlbums(forArtist: artistId) }
    func getAlbums(forGenre genre: String) async throws -> [AlbumDTO] { try await repo.getAlbums(forGenre: genre) }
    func search(query: String) async throws -> SearchResults { try await repo.search(query: query) }
    func getCoverImage(for id: String, size: Int = 300) async -> UIImage? { await coverCache.getImage(for: id, size: size) }
    func performSync(force: Bool = false) async throws { try await sync.performSmartSync(force: force) }
    func cancelSync() async { await sync.cancelSync() }
    func syncAlbumDetails(albumId: String) async throws { try await sync.syncAlbumDetails(albumId: albumId) }
}

@Observable @MainActor
final class PlaybackEnvironment {
    private let engine: AudioEngine
    var isPlaying: Bool { engine.isPlaying }
    var currentSongId: String? { engine.currentSongId }
    var currentTitle: String { engine.currentTitle }
    var currentArtist: String { engine.currentArtist }
    var currentCoverId: String? { engine.currentCoverId }
    var progress: Double { engine.progress }
    var duration: Double { engine.duration }
    var errorMessage: String? { engine.errorMessage }
    var isShuffled: Bool { engine.isShuffled }
    var repeatMode: RepeatMode { engine.repeatMode }
    init(engine: AudioEngine) { self.engine = engine }
    func play() { engine.play() }
    func pause() { engine.pause() }
    func seek(to seconds: Double) { engine.seek(to: seconds) }
    func skipToNext() { engine.skipToNext() }
    func skipToPrevious() { engine.skipToPrevious() }
    func toggleShuffle() { engine.toggleShuffle() }
    func toggleRepeat() { engine.toggleRepeat() }
    func setupPlayer(with songId: String, queue: [String], autoPlay: Bool = true) async {
        await engine.setupPlayer(with: songId, queue: queue, autoPlay: autoPlay)
    }
}

@Observable @MainActor
final class DownloadEnvironment {
    private let manager: DownloadManager
    
    var activeDownloads: Set<String> { manager.activeDownloads }
    
    var storage: DownloadStorage { manager.storage }
    
    init(manager: DownloadManager) { self.manager = manager }
    
    func isDownloading(songId: String) -> Bool {
        activeDownloads.contains(songId)
    }
    
    func idDownloaded(songId: String) -> Bool { manager.isPinned(songId: songId) }
    
    func isAlbumFullyDownloaded(songIds: [String]) -> Bool { manager.isAlbumFullyDownloaded(songIds: songIds) }
    
    func isDownloading(albumId: String) -> Bool { manager.isDownloading(albumId: albumId) }
    
    func download(song: SongDTO) async { await manager.downloadSong(id: song.id, path: song.path, coverId: song.coverArtId) }
    
    func downloadAlbum(albumId: String, songs: [SongDTO]) async {
        await manager.downloadAlbum(albumId: albumId, songs: songs.map { ($0.id, $0.path, $0.coverArtId) })
    }
    func deleteDownload(songId: String) { manager.deleteDownload(songId: songId) }
}

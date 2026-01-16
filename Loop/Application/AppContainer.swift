//
//  AppContainer.swift
//  Loop
//
//  Dependency Injection Container
//

import Foundation
import Observation

@Observable
final class AppContainer {
    
    // Services
    let authService: AuthenticationService
    let client: NavidromeClient
    let db: MusicDatabase
    let repo: MusicRepository
    let syncManager: SyncManager
    let downloads: DownloadManager
    let coverCache: CoverArtCache
    let audio: AudioEngine
    
    // Navigation
    var router = Router()
    
    init() {
        let client = NavidromeClient()
        let db = MusicDatabase()
        let repo = MusicRepository(db: db) // Pure DB repo
        let coverCache = CoverArtCache(client: client)
        let downloads = DownloadManager(client: client)
        
        let syncManager = SyncManager(repo: repo, client: client, cache: coverCache)
        let authService = AuthenticationService(client: client, syncManager: syncManager)
        
        let assetProvider = SmartAssetProvider(client: client, downloadManager: downloads)
        
        let audio = AudioEngine(
            provider: assetProvider,
            stateStore: UserDefaultsPersistence(),
            repo: repo,
            coverCache: coverCache
        )
        
        self.client = client
        self.db = db
        self.repo = repo
        self.syncManager = syncManager
        self.downloads = downloads
        self.coverCache = coverCache
        self.authService = authService
        self.audio = audio
    }
}

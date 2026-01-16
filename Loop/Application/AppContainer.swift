//
//  AppContainer.swift
//  Loop
//
//  Simplified dependency injection - no business logic
//

import Foundation
import Observation

@Observable
final class AppContainer {
    
    var isAuthenticated: Bool = false
    
    // Core Dependencies
    let client: NavidromeClient
    let db: MusicDatabase
    let repo: MusicRepository
    let downloads: DownloadManager
    let coverCache: CoverArtCache
    let syncManager: SyncManager
    let audio: AudioEngine
    
    // Navigation
    var router = Router()
    
    init() {
        // Check auth status
        let hasCredentials = Task {
            await KeychainStorage.shared.credentials != nil
        }
        
        self.isAuthenticated = false // Will be updated after async check
        
        let client = NavidromeClient()
        let db = MusicDatabase()
        let repo = MusicRepository(db: db)
        let coverCache = CoverArtCache(client: client)
        
        self.client = client
        self.db = db
        self.repo = repo
        self.coverCache = coverCache
        self.downloads = DownloadManager(client: client)
        self.syncManager = SyncManager(repo: repo, client: client, cache: coverCache)
        
        let assetProvider = SmartAssetProvider(client: client, downloadManager: self.downloads)
        
        self.audio = AudioEngine(
            provider: assetProvider,
            stateStore: UserDefaultsPersistence(),
            repo: repo,
            coverCache: coverCache
        )
        
        // Check credentials async
        Task { @MainActor in
            self.isAuthenticated = await KeychainStorage.shared.credentials != nil
        }
    }
    
    func login(credentials: Credentials) async throws {
        // Save to keychain
        try await KeychainStorage.shared.save(credentials: credentials)
        
        // Update client
        await client.updateCredentials(credentials)
        
        // Test connection
        let _: SubsonicPingResponse = try await client.fetch("ping")
        
        self.isAuthenticated = true
        
        // Trigger initial sync in background
        Task {
            try? await syncManager.performSmartSync()
        }
    }
    
    func logout() async {
        await KeychainStorage.shared.clear()
        self.isAuthenticated = false
    }
}

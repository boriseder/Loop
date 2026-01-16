//
//  AppContainer.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
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
    let audio: AudioEngine
    
    // Navigation
    var router = Router()
    
    init() {
        // Check Auth Status on Launch
        self.isAuthenticated = CredentialStorage.shared.hasCredentials
        
        let client = NavidromeClient()
        let db = MusicDatabase()
        
        self.client = client
        self.db = db
        
        self.repo = MusicRepository(db: db, client: client)
        self.downloads = DownloadManager(client: client)
        
        let assetProvider = SmartAssetProvider(client: client, downloadManager: self.downloads)
        
        self.audio = AudioEngine(
            provider: assetProvider,
            stateStore: UserDefaultsPersistence(),
            repo: self.repo,
            client: client
        )
    }
    
    func login(url: String, user: String, pass: String) {
        let store = CredentialStorage.shared
        store.baseURL = url
        store.username = user
        store.password = pass
        
        self.isAuthenticated = true
        // Trigger initial sync after login
        Task { await repo.syncSmart { _ in } }
    }
    
    func logout() {
        CredentialStorage.shared.clear()
        self.isAuthenticated = false
        // Optional: Clear DB here if you want a full wipe
        // db.clearAll()
    }
}

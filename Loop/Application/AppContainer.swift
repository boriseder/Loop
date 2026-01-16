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
    
    // Core Dependencies
    let client: NavidromeClient
    let db: MusicDatabase
    let repo: MusicRepository
    let downloads: DownloadManager
    let audio: AudioEngine
    
    // Navigation
    var router = Router()
    
    init() {
        // 1. Setup Client & DB
        let client = NavidromeClient()
        let db = MusicDatabase()
        
        self.client = client
        self.db = db
        
        // 2. Setup Repo & Downloads
        self.repo = MusicRepository(db: db, client: client)
        self.downloads = DownloadManager(client: client)
        
        // 3. Setup Audio Stack
        let assetProvider = SmartAssetProvider(client: client, downloadManager: self.downloads)
        
        // ✅ FIX: Use 'UserDefaultsPersistence()' (Concrete) instead of 'PlaybackPersistence()' (Protocol)
        self.audio = AudioEngine(
            provider: assetProvider,
            stateStore: UserDefaultsPersistence(),
            repo: self.repo,
            client: client
        )
    }
}

//
//  AppContainer.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import SwiftData
import Observation

@Observable
final class AppContainer {
    
    // Core Services
    let client: NavidromeClient
    let db: MusicDatabase
    let repo: MusicRepository
    let router: Router
    
    // Feature Services
    let downloads: DownloadManager
    let audio: AudioEngine
    
    init() {
        // 1. Foundation
        self.client = NavidromeClient()
        self.db = MusicDatabase()
        self.router = Router()
        
        // 2. Data Layer
        self.repo = MusicRepository(db: db, client: client)
        
        // 3. Downloads (Now constructed correctly)
        // ✅ FIX: Pass 'client' to the init
        self.downloads = DownloadManager(client: client)
        
        // 4. Persistence
        let persistence = UserDefaultsPlaybackPersistence()
        
        // 5. Audio Engine
        self.audio = AudioEngine(
            provider: downloads, // ✅ Now conforms to AssetProvider
            stateStore: persistence,
            repo: repo,
            client: client
        )
        
        print("✅ Loop AppContainer Initialized")
    }
}

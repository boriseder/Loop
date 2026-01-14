//
//  AppContainer.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation

@Observable @MainActor
final class AppContainer {
    
    // MARK: - Level 0: Pure Utilities
    let client: NavidromeClient
    let database: MusicDatabase
    let router: Router
    let networkMonitor: NetworkMonitor
    
    // MARK: - Level 1: Data Services
    let repo: MusicRepository
    let downloads: DownloadManager
    let playbackState: PlaybackPersistence
    
    // MARK: - Level 2: Coordinators
    let audio: AudioEngine
    
    init() {
        // 0. Initialize Utilities
        self.client = NavidromeClient()
        self.database = MusicDatabase()
        self.router = Router()
        self.networkMonitor = NetworkMonitor()
        
        // 1. Initialize Services
        self.repo = MusicRepository(db: database, client: client)
        self.downloads = DownloadManager(client: client)
        self.playbackState = PlaybackPersistence()
        
        // 2. Initialize Coordinators
        // The "Smart" provider needs access to Downloads, Network, and Client
        let provider = SmartAssetProvider(
            downloads: downloads,
            networkMonitor: networkMonitor,
            client: client
        )

        // ✅ FIX: Inject 'repo' and 'client' dependencies
        self.audio = AudioEngine(
            provider: provider,
            stateStore: playbackState,
            repo: repo,
            client: client
        )
        
        print("✅ Loop AppContainer Initialized")
    }
}

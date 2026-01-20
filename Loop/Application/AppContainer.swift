import Foundation
import SwiftData

@MainActor
final class AppContainer {
    // Core
    let db: MusicDatabase
    let client: NavidromeClient
    
    // Services
    let repo: MusicRepository
    let syncManager: SyncManager
    let downloadManager: DownloadManager
    let authService: AuthenticationService
    let coverCache: CoverArtCache
    
    // Engine
    let audioEngine: AudioEngine
    
    // UI State
    let downloadFilter: DownloadFilter
    
    init() {
        self.db = MusicDatabase()
        self.client = NavidromeClient()
        
        self.repo = MusicRepository(db: db)
        self.coverCache = CoverArtCache(client: client)
        self.downloadManager = DownloadManager(client: client)
        self.syncManager = SyncManager(client: client, container: db.container)
        
        self.authService = AuthenticationService(client: client, syncManager: syncManager)
        
        let assetProvider = SmartAssetProvider(client: client, downloadManager: downloadManager)
        self.audioEngine = AudioEngine(provider: assetProvider, repo: repo, coverCache: coverCache)
        
        self.downloadFilter = DownloadFilter()
    }
}

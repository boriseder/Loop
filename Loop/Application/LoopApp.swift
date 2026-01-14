//
//  LoopApp.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import SwiftData
import AVFoundation // ⚠️ CRITICAL: This import fixes the "Cannot find AVAudioSession" error

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    
    // Configure Global Cache on Init
    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            directory: nil
        )
    }
    
    var body: some Scene {
        WindowGroup {
            @Bindable var router = container.router
            
            NavigationStack(path: $router.path) {
                LibraryView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        switch destination {
                        case .albumDetail(let id):
                            AlbumDetailView(albumId: id)
                        case .artistDetail(let id):
                            Text("Artist \(id)")
                        case .player:
                            Text("Full Player")
                        case .settings:
                            Text("Settings")
                        }
                    }
            }
            .overlay(alignment: .bottom) {
                if container.audio.currentSongId != nil {
                    MiniPlayerView()
                }
            }
            .environment(container)
            .onAppear {
                // 1. Tell the system we want to handle remote controls
                UIApplication.shared.beginReceivingRemoteControlEvents()
                
                // 2. Activate Audio Session
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("❌ Audio Session Launch Error: \(error)")
                }
            }
        }
    }
}

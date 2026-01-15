//
//  LoopApp.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import SwiftData
import AVFoundation

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    
    init() {
        // Configure Global Cache
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            directory: nil
        )
    }
    
    var body: some Scene {
        WindowGroup {
            // ✅ FIX: Create a Bindable proxy for the router
            @Bindable var router = container.router
            
            // We use a ZStack to float the MiniPlayer above the TabBar
            ZStack(alignment: .bottom) {
                
                // 1. Main Tab Interface
                TabView {
                    // TAB 1: Library
                    NavigationStack(path: $router.path) {
                        LibraryView()
                            .navigationDestination(for: Router.Destination.self) { destination in
                                switch destination {
                                case .albumDetail(let id):
                                    AlbumDetailView(albumId: id)
                                case .artistDetail(let id):
                                    Text("Artist \(id)") // Placeholder for now
                                case .player:
                                    Text("Full Player")
                                case .settings:
                                    Text("Settings")
                                }
                            }
                    }
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                    
                    // TAB 2: Search (Independent Stack)
                    SearchView()
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                }
                // IMPORTANT: Add padding to prevent content from being hidden behind MiniPlayer
                .safeAreaPadding(.bottom, container.audio.currentSongId != nil ? 60 : 0)
                
                // 2. Global Mini Player Overlay
                if container.audio.currentSongId != nil {
                    MiniPlayerView()
                        .padding(.bottom, 49) // Lift above standard TabBar height
                        .transition(.move(edge: .bottom))
                }
            }
            .environment(container)
            .onAppear {
                // System Setup
                UIApplication.shared.beginReceivingRemoteControlEvents()
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

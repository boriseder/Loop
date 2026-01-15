//
//  LoopApp.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    @State private var isPlayerPresented = false
    
    var body: some Scene {
        WindowGroup {
            @Bindable var router = container.router
            
            NavigationStack(path: $router.path) {
                LibraryView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        container.router.view(for: destination)
                    }
            }
            .environment(container) // ✅ Injected for Library & MiniPlayer
            .overlay(alignment: .bottom) {
                if container.audio.currentSongId != nil {
                    MiniPlayerView()
                        .padding(.bottom, 20)
                        .padding(.horizontal, 12)
                        .onTapGesture {
                            isPlayerPresented = true
                        }
                        .transition(.move(edge: .bottom))
                }
            }
            /*
            .sheet(isPresented: $isPlayerPresented) {
                PlayerView(isPresented: $isPlayerPresented)
                    .presentationDragIndicator(.visible)
                    .environment(container) // ✅ Explicitly inject into Sheet to prevent crashes
            }
             */
        }
    }
}

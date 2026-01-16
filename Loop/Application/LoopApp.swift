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
            ContentView()
                .environment(container)
        }
    }
}

// ✅ NEW: Separate content view to ensure environment is established first
struct ContentView: View {
    @Environment(AppContainer.self) private var container
    @State private var isPlayerPresented = false
    
    var body: some View {
        @Bindable var router = container.router
        
        NavigationStack(path: $router.path) {
            LibraryView()
                .navigationDestination(for: Router.Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
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
    }
    
    // ✅ FIX: Create destination views here where environment is available
    @ViewBuilder
    private func destinationView(for destination: Router.Destination) -> some View {
        switch destination {
        case .albumDetail(let id):
            AlbumDetailView(albumId: id)
        case .artistDetail(let id):
            ArtistDetailView(artistId: id)
        case .genreDetail(let name):
            GenreDetailView(genreName: name)
        }
    }
}

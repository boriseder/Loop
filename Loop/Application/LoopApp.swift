//
//  LoopApp.swift
//  Loop
//
//  FIXED: Removed TabView, single NavigationStack with proper destinations
//

import SwiftUI

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    @State private var isPlayerPresented = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if container.auth.isAuthenticated {
                    AuthenticatedRoot()
                } else {
                    LoginView()
                }
            }
            .environment(container.auth)
            .environment(container.music)
            .environment(container.playback)
            .environment(container.downloads)
            .environment(container.router)
            .overlay {
                if container.music.isSyncing {
                    SyncProgressView(
                        progress: container.music.syncProgress,
                        onCancel: {
                            Task {
                                await container.music.cancelSync()
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut, value: container.music.isSyncing)
        }
    }
    
    @ViewBuilder
    private func AuthenticatedRoot() -> some View {
        @Bindable var router = container.router
        
        // ✅ FIXED: Single NavigationStack without TabView
        NavigationStack(path: $router.path) {
            LibraryView()
                .navigationDestination(for: Router.Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .overlay(alignment: .bottom) {
            // ✅ FIXED: Only show if actually playing
            if container.playback.currentSongId != nil && container.playback.currentTitle != "Not Playing" {
                MiniPlayerView()
                    .padding(.bottom, 8)
                    .padding(.horizontal, 12)
                    .onTapGesture { isPlayerPresented = true }
                    .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView(isPresented: $isPlayerPresented)
                .presentationDragIndicator(.visible)
        }
    }
    
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

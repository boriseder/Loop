//
//  LoopApp.swift
//  Loop
//
//  FIXED: Shows sync progress modal
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
            // ✅ NEW: Show sync progress modal
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
        
        // ✅ NEW: TabView with Library and Downloads
        TabView {
            NavigationStack(path: $router.path) {
                LibraryView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Library", systemImage: "square.stack")
            }
            
            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
        }
        .overlay(alignment: .bottom) {
            if container.playback.currentSongId != nil {
                MiniPlayerView()
                    .padding(.bottom, 70) // ✅ Adjusted for tab bar
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

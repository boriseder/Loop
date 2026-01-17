//
//  LoopApp.swift
//  Loop
//
//  FIXED: Pass filter state to ArtistDetailView
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
                        onCancel: { Task { await container.music.cancelSync() } }
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
        
        NavigationStack(path: $router.path) {
            LibraryView()
                .navigationDestination(for: Router.Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .overlay(alignment: .bottom) {
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
        // ✅ UPDATE: Pass flag
        case .artistDetail(let id, let showDownloaded):
            ArtistDetailView(artistId: id, showDownloadedOnly: showDownloaded)
        case .genreDetail(let name, let showDownloaded):
            GenreDetailView(genreName: name, showDownloadedOnly: showDownloaded)
        case .downloads:
            DownloadsView()
        }
    }
}

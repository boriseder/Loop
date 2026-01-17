//
//  LoopApp.swift
//  Loop
//
//  FIXED: Splash Screen, Single NavigationStack, Global Progress
//

import SwiftUI

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    @State private var isPlayerPresented = false
    @State private var isReady = false // Gatekeeper for initialization
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isReady {
                    if container.auth.isAuthenticated {
                        AuthenticatedRoot()
                            .transition(.opacity)
                    } else {
                        LoginView()
                            .transition(.opacity)
                    }
                } else {
                    SplashScreen()
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
            .task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation {
                    isReady = true
                }
            }
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
        case .artistDetail(let id):
            ArtistDetailView(artistId: id)
        case .genreDetail(let name):
            GenreDetailView(genreName: name)
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "infinity.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: true)
                Text("Loop")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
            }
        }
    }
}

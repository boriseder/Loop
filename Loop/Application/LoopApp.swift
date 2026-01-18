//
//  LoopApp.swift
//  Loop
//
//  FIXED: Replaced Splash Screen with Library Skeleton for seamless launch
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
                    // ✅ NEW: Show Skeleton instead of Splash
                    LaunchSkeletonView()
                        .transition(.opacity)
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
                // Wait for Keychain read to complete
                // We keep a small delay to prevent a harsh "flash" if auth is instant
                async let check: Void = container.auth.restoreSession()
                async let minimumDelay: Void = Task.sleep(nanoseconds: 500_000_000) // 0.5s skeleton
                
                _ = try? await (check, minimumDelay)
                
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
        case .artistDetail(let id, let showDownloaded):
            ArtistDetailView(artistId: id, showDownloadedOnly: showDownloaded)
        case .genreDetail(let name, let showDownloaded):
            GenreDetailView(genreName: name, showDownloadedOnly: showDownloaded)
        case .downloads:
            DownloadsView()
        }
    }
}

// MARK: - Launch Skeleton
// Replicates the LibraryView structure for a seamless transition

struct LaunchSkeletonView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fake Filter Bar (Matches LibraryView)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        fakeFilterChip("Albums", isSelected: true)
                        fakeFilterChip("Artists", isSelected: false)
                        fakeFilterChip("Genres", isSelected: false)
                    }
                    .padding()
                }
                .background(Material.regular)
                
                // Skeleton Grid
                AlbumGridSkeleton()
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Fake Toolbar Items to match layout
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func fakeFilterChip(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
    }
}

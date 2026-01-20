import SwiftUI

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            if container.authService.isAuthenticated {
                AuthenticatedRoot(container: container)
            } else {
                LoginView(auth: container.authService)
            }
        }
    }
}

struct AuthenticatedRoot: View {
    let container: AppContainer
    @State private var router = Router()
    @State private var isPlayerPresented = false
    
    var body: some View {
        ZStack {
            NavigationStack(path: $router.path) {
                LibraryView(
                    viewModel: LibraryViewModel(
                        repo: container.repo,
                        syncManager: container.syncManager,
                        downloader: container.downloadManager,
                        filter: container.downloadFilter
                    ),
                    container: container
                )
                .navigationDestination(for: Router.Destination.self) { dest in
                    destinationView(for: dest)
                }
                .environment(router)
            }
            
            // Global MiniPlayer overlay
            VStack {
                Spacer()
                if container.audioEngine.currentSong != nil {
                    MiniPlayerView(audio: container.audioEngine, cache: container.coverCache)
                        .onTapGesture {
                            isPlayerPresented = true
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: container.audioEngine.currentSong != nil)
        }
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView(
                audio: container.audioEngine,
                cache: container.coverCache,
                isPresented: $isPlayerPresented
            )
            .presentationDragIndicator(.visible)
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: Router.Destination) -> some View {
        switch destination {
        case .albumDetail(let id):
            AlbumDetailView(
                vm: AlbumDetailViewModel(
                    albumId: id,
                    repo: container.repo,
                    sync: container.syncManager,
                    downloader: container.downloadManager,
                    audio: container.audioEngine
                ),
                cache: container.coverCache
            )
            
        case .artistDetail(let id, _):
            ArtistDetailView(
                vm: ArtistDetailViewModel(
                    artistId: id,
                    repo: container.repo,
                    downloader: container.downloadManager,
                    filter: container.downloadFilter
                ),
                container: container
            )
            
        case .genreDetail(let name, _):
            GenreDetailView(
                vm: GenreDetailViewModel(
                    genreName: name,
                    repo: container.repo,
                    downloader: container.downloadManager,
                    filter: container.downloadFilter
                ),
                container: container
            )
        }
    }
}

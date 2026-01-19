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
        NavigationStack(path: $router.path) {
            LibraryView(
                viewModel: LibraryViewModel(repo: container.repo, syncManager: container.syncManager),
                container: container
            )
            .navigationDestination(for: Router.Destination.self) { dest in
                switch dest {
                case .albumDetail(let id):
                    AlbumDetailView(
                        vm: AlbumDetailViewModel(
                            albumId: id,
                            repo: container.repo,
                            sync: container.syncManager,
                            downloader: container.downloadManager,
                            audio: container.audioEngine
                        ),
                        cache: container.coverCache // ✅ Passed cache
                    )
                    
                case .artistDetail(let id, let showDownloaded):
                    ArtistDetailView(
                        vm: ArtistDetailViewModel(
                            artistId: id,
                            showDownloadedOnly: showDownloaded,
                            repo: container.repo,
                            downloader: container.downloadManager
                        ),
                        container: container
                    )
                    
                case .genreDetail(let name, _): // Assuming filtered view handles showDownloaded internally or we pass it
                    GenreDetailView(
                        vm: GenreDetailViewModel(genreName: name, repo: container.repo),
                        container: container
                    )
                    
                case .downloads:
                    DownloadsView(
                        repo: container.repo,
                        downloader: container.downloadManager,
                        cache: container.coverCache
                    )
                }
            }
        }
        .environment(router)
        .overlay(alignment: .bottom) {
            if container.audioEngine.currentSong != nil {
                MiniPlayerView(audio: container.audioEngine)
                    .onTapGesture {
                        isPlayerPresented = true
                    }
            }
        }
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView(
                audio: container.audioEngine, // ✅ Passed audio
                cache: container.coverCache,  // ✅ Passed cache
                isPresented: $isPlayerPresented
            )
            .presentationDragIndicator(.visible)
        }
    }
}

import SwiftUI

struct LibraryView: View {
    @State var viewModel: LibraryViewModel
    let container: AppContainer
    @Environment(Router.self) private var router
    
    @State private var showSearch = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Scope Bar
            Picker("Scope", selection: $viewModel.scope) {
                Text("Albums").tag(LibraryViewModel.LibraryScope.albums)
                Text("Artists").tag(LibraryViewModel.LibraryScope.artists)
                Text("Genres").tag(LibraryViewModel.LibraryScope.genres)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .frame(maxHeight: .infinity)
                
            case .error(let msg):
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(msg)
                )
                
            case .empty:
                if container.downloadFilter.showDownloadedOnly {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("You haven't downloaded any music yet")
                    )
                } else {
                    ContentUnavailableView(
                        "Empty Library",
                        systemImage: "music.note",
                        description: Text("Sync your music to get started")
                    )
                }
                
            case .content:
                ScrollView {
                    contentGrid
                        .padding(.bottom, 100)
                }
                .refreshable {
                    viewModel.refresh()
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Download filter
                    Button {
                        container.downloadFilter.showDownloadedOnly.toggle()
                        viewModel.filterToggled()
                    } label: {
                        Label(
                            container.downloadFilter.showDownloadedOnly
                                ? "Show All"
                                : "Downloaded Only",
                            systemImage: container.downloadFilter.showDownloadedOnly
                                ? "arrow.down.circle.fill"
                                : "arrow.down.circle"
                        )
                    }

                    // Search
                    Button {
                        showSearch = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Sync Progress Overlay
            if container.syncManager.progress.isActive {
                SyncProgressView(
                    progress: container.syncManager.progress,
                    onCancel: {
                        container.syncManager.cancelSync()
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut, value: container.syncManager.progress.isActive)
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showSearch) {
            SearchView(
                repo: container.repo,
                router: router
            )
        }
    }
    
    @ViewBuilder
    private var contentGrid: some View {
        switch viewModel.scope {
        case .albums:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(viewModel.albums) { album in
                    Button {
                        router.navigateToAlbum(album.id)
                    } label: {
                        AlbumCell(album: album, cache: container.coverCache)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            
        case .artists:
            LazyVStack(spacing: 0) {
                ForEach(viewModel.artists) { artist in
                    Button {
                        router.navigateToArtist(artist.id)
                    } label: {
                        ArtistRow(artist: artist)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().padding(.leading)
                }
            }
            
        case .genres:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(viewModel.genres) { genre in
                    Button {
                        router.navigateToGenre(genre.name)
                    } label: {
                        GenreCell(genre: genre)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

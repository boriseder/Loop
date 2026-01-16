//
//  LibraryView.swift
//  Loop
//
//  Fixed: Missing argument labels in NavigationLink destinations
//

import SwiftUI

struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: LibraryViewModel?
    
    // Grid configuration
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if let vm = viewModel {
                mainContent(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LibraryViewModel(
                    repo: container.repo,
                    syncManager: container.syncManager
                )
            }
        }
        .task {
            await viewModel?.loadInitialData()
        }
    }
    
    @ViewBuilder
    private func mainContent(_ vm: LibraryViewModel) -> some View {
        VStack(spacing: 0) {
            // Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    filterChip("Recent", scope: .recent, vm: vm)
                    filterChip("Artists", scope: .artists, vm: vm)
                    filterChip("Genres", scope: .genres, vm: vm)
                }
                .padding()
            }
            .background(Material.regular)
            
            // Content
            ScrollView {
                if vm.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    contentGrid(vm)
                        .padding()
                }
            }
            .refreshable {
                await vm.refresh()
            }
        }
        .navigationTitle("Library")
        .overlay(alignment: .bottom) {
            if let msg = vm.statusMessage {
                Text(msg)
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    @ViewBuilder
    private func filterChip(_ title: String, scope: LibraryViewModel.LibraryScope, vm: LibraryViewModel) -> some View {
        Button {
            vm.scope = scope
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(vm.scope == scope ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(vm.scope == scope ? .white : .primary)
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func contentGrid(_ vm: LibraryViewModel) -> some View {
        switch vm.scope {
        case .recent:
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(vm.recentAlbums) { album in
                    // ✅ FIX: Added 'albumId:' argument label
                    NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                        AlbumCell(album: album)
                    }
                }
            }
            
        case .artists:
            LazyVStack(spacing: 0) {
                ForEach(vm.artists) { artist in
                    // ✅ FIX: Added 'artistId:' argument label
                    NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id)) {
                        HStack {
                            Text(artist.name)
                                .font(.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .padding(.bottom, 8)
                }
            }
            
        case .genres:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)]) {
                ForEach(vm.genres) { genre in
                    // ✅ FIX: Added 'genreName:' argument label
                    NavigationLink(value: Router.Destination.genreDetail(genreName: genre.name)) {
                        VStack {
                            Text(genre.name)
                                .font(.headline)
                            Text("\(genre.albumCount) albums")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// Helper Cell
struct AlbumCell: View {
    let album: Loop.Album
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverArtView(coverArtId: album.coverArtId, size: 180)
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(12)
            
            Text(album.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(album.artist?.name ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

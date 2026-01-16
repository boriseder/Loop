//
//  LibraryView.swift
//  Loop
//
//  FIXED: Uses MusicEnvironment, supports infinite scroll
//

import SwiftUI

struct LibraryView: View {
    @Environment(MusicEnvironment.self) private var music
    @Environment(Router.self) private var router
    @State private var viewModel: LibraryViewModel?
    
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
                viewModel = LibraryViewModel(music: music)
                Task {
                    await viewModel?.loadInitialData()
                }
            }
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
                if vm.isLoading && vm.recentAlbums.isEmpty && vm.artists.isEmpty && vm.genres.isEmpty {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
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
                    NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                        AlbumCell(album: album)
                    }
                    .buttonStyle(.plain)
                    .task {
                        // Trigger load more when near the end
                        if album.id == vm.recentAlbums.last?.id {
                            await vm.loadMore()
                        }
                    }
                }
            }
            
        case .artists:
            LazyVStack(spacing: 0) {
                ForEach(vm.artists) { artist in
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
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .task {
                        // Trigger load more when near the end
                        if artist.id == vm.artists.last?.id {
                            await vm.loadMore()
                        }
                    }
                }
            }
            
        case .genres:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)]) {
                ForEach(vm.genres) { genre in
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
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Album Cell Component

struct AlbumCell: View {
    let album: AlbumDTO
    @Environment(MusicEnvironment.self) private var music
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderView
                }
            }
            .frame(width: 180, height: 180)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            
            Text(album.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)
            
            Text(album.artistName ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .task(id: album.coverArtId) {
            if let coverId = album.coverArtId {
                coverImage = await music.getCoverImage(for: coverId, size: 360)
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
        }
    }
}

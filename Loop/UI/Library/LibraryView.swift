//
//  LibraryView.swift
//  Loop
//
//  OPTIMIZED: High-performance scrolling (Removed staggering & enumeration)
//

import SwiftUI

struct LibraryView: View {
    @Environment(MusicEnvironment.self) private var music
    @Environment(DownloadEnvironment.self) private var downloads
    @State private var viewModel: LibraryViewModel?
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showDownloadedOnly = false
    
    // Fixed column size is more performant than adaptive for images
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if let vm = viewModel {
                mainContent(vm)
            } else {
                loadingView
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LibraryViewModel(music: music, downloads: downloads)
            }
        }
        .task {
            if let vm = viewModel {
                await vm.loadInitialData()
            }
        }
        .sheet(isPresented: $showSearch) { SearchView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
    
    private var loadingView: some View {
        VStack {
            AlbumGridSkeleton()
        }
    }
    
    @ViewBuilder
    private func mainContent(_ vm: LibraryViewModel) -> some View {
        VStack(spacing: 0) {
            // Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    filterChip("Albums", scope: .recent, vm: vm)
                    filterChip("Artists", scope: .artists, vm: vm)
                    filterChip("Genres", scope: .genres, vm: vm)
                }
                .padding()
            }
            .background(Material.regular)
            
            // Main Content
            ScrollView {
                // Optimization: Simple check avoids View tree complexity
                if vm.isLoading && vm.filteredAlbums.isEmpty {
                    AlbumGridSkeleton()
                } else if vm.filteredAlbums.isEmpty && vm.filteredArtists.isEmpty && vm.filteredGenres.isEmpty {
                    ContentUnavailableView("No Music", systemImage: "music.note", description: Text("Library is empty"))
                        .padding(.top, 50)
                } else {
                    contentGrid(vm)
                        .padding()
                }
            }
            .refreshable { await vm.refresh() }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button { showSearch = true } label: { Label("Search", systemImage: "magnifyingglass") }
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gear") }
                    Divider()
                    Toggle(isOn: $showDownloadedOnly) { Label("Downloaded Only", systemImage: "arrow.down.circle") }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onChange(of: showDownloadedOnly) { _, newValue in
            Task { await viewModel?.updateFilter(downloadedOnly: newValue) }
        }
        .overlay(alignment: .bottom) {
            if let msg = vm.statusMessage {
                Text(msg)
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
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
                // OPTIMIZED: Direct iteration, no Array creation, no Enumeration
                ForEach(vm.filteredAlbums) { album in
                    NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                        AlbumCell(album: album)
                    }
                    .buttonStyle(.plain)
                    // REMOVED: .staggeredAppear (Major lag cause)
                    .task {
                        // Prefetch logic
                        if album.id == vm.filteredAlbums.last?.id {
                            await vm.loadMore()
                        }
                    }
                }
            }
            
        case .artists:
            LazyVStack(spacing: 0) {
                ForEach(vm.filteredArtists) { artist in
                    NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id)) {
                        HStack {
                            Text(artist.name).font(.body)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .task {
                        if artist.id == vm.filteredArtists.last?.id {
                            await vm.loadMore()
                        }
                    }
                }
            }
            
        case .genres:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)]) {
                ForEach(vm.filteredGenres) { genre in
                    NavigationLink(value: Router.Destination.genreDetail(genreName: genre.name)) {
                        VStack(spacing: 8) {
                            Text(genre.name)
                                .font(.headline)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(minHeight: 44)
                            Text("\(genre.albumCount) albums")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
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

// MARK: - Optimized Album Cell
struct AlbumCell: View {
    let album: AlbumDTO
    @Environment(MusicEnvironment.self) private var music
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                } else {
                    Color.secondary.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .frame(width: 160, height: 160) // Fixed size is faster for layout
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text(album.artistName ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle()) // Improves hit testing performance
        .task(id: album.coverArtId) {
            // Load image only when visible
            if let coverId = album.coverArtId {
                // Logic is handled by Actor, safe for main thread
                coverImage = await music.getCoverImage(for: coverId, size: 300)
            }
        }
    }
}

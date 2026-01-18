//
//  LibraryView.swift
//  Loop
//
//  FIXED: Integrated skeleton for seamless loading
//

import SwiftUI

struct LibraryView: View {
    @Environment(MusicEnvironment.self) private var music
    @Environment(DownloadEnvironment.self) private var downloads
    @Environment(Router.self) private var router
    
    @State private var viewModel: LibraryViewModel?
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showDownloadedOnly = false
    @State private var isInitialLoad = true // ✅ NEW: Track initial load
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar (Always visible)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let vm = viewModel {
                        filterChip("Albums", scope: .recent, vm: vm)
                        filterChip("Artists", scope: .artists, vm: vm)
                        filterChip("Genres", scope: .genres, vm: vm)
                    } else {
                        // Skeleton chips
                        fakeFilterChip("Albums", isSelected: true)
                        fakeFilterChip("Artists", isSelected: false)
                        fakeFilterChip("Genres", isSelected: false)
                    }
                }
                .padding()
            }
            .background(Material.regular)
            
            // Main Content Area
            Group {
                if isInitialLoad {
                    // ✅ Show skeleton during initial load
                    skeletonContent
                } else if let vm = viewModel {
                    mainContent(vm)
                } else {
                    skeletonContent
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button { showSearch = true } label: { Label("Search", systemImage: "magnifyingglass") }
                    Button {
                        Task { await viewModel?.refresh(force: true) }
                    } label: {
                        Label("Force Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gear") }
                    Divider()
                    Toggle(isOn: $showDownloadedOnly) { Label("Downloaded Only", systemImage: "arrow.down.circle") }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.navigateToDownloads()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
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
                // Small delay to show skeleton
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isInitialLoad = false
                }
            }
        }
        .sheet(isPresented: $showSearch) { SearchView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onChange(of: showDownloadedOnly) { _, newValue in
            Task { await viewModel?.updateFilter(downloadedOnly: newValue) }
        }
        .overlay(alignment: .bottom) {
            if let vm = viewModel, let msg = vm.statusMessage {
                Text(msg)
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
            }
        }
    }
    
    // ✅ NEW: Skeleton Content
    private var skeletonContent: some View {
        ScrollView {
            VStack {
                AlbumGridSkeleton()
                    .padding()
                
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading library...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(_ vm: LibraryViewModel) -> some View {
        if vm.filteredAlbums.isEmpty && vm.filteredArtists.isEmpty && vm.filteredGenres.isEmpty && !vm.isLoading {
            ContentUnavailableView(
                "No Music",
                systemImage: "music.note",
                description: Text("Library is empty. Try syncing or downloading music.")
            )
            .padding(.top, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                contentGrid(vm)
                    .padding()
                
                if vm.isLoading && !vm.filteredAlbums.isEmpty {
                    ProgressView()
                        .padding()
                }
            }
            .refreshable { await vm.refresh(force: true) }
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
    
    private func fakeFilterChip(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func contentGrid(_ vm: LibraryViewModel) -> some View {
        switch vm.scope {
        case .recent:
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(vm.filteredAlbums) { album in
                    NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                        AlbumCell(album: album)
                    }
                    .buttonStyle(.plain)
                    .task {
                        if album.id == vm.filteredAlbums.last?.id {
                            await vm.loadMore()
                        }
                    }
                }
            }
            
        case .artists:
            LazyVStack(spacing: 0) {
                ForEach(vm.filteredArtists) { artist in
                    NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id, showDownloadedOnly: vm.showDownloadedOnly)) {
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
                    NavigationLink(value: Router.Destination.genreDetail(genreName: genre.name, showDownloadedOnly: vm.showDownloadedOnly)) {
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
            .frame(width: 160, height: 160)
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
        .contentShape(Rectangle())
        .task(id: album.coverArtId) {
            if let coverId = album.coverArtId {
                coverImage = await music.getCoverImage(for: coverId, size: 300)
            }
        }
    }
}

//
//  LibraryView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: LibraryViewModel?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            contentView
        }
        .navigationTitle("Library")
        .searchable(text: Binding(get: { viewModel?.searchText ?? "" }, set: { viewModel?.searchText = $0 }), prompt: "Filter...")
        .toolbar {
            toolbarContent
        }
        // ✅ MINIMALISTIC PROGRESS BAR
        .safeAreaInset(edge: .top) {
            if let vm = viewModel, vm.isSyncing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(height: 3)
                    .tint(.accentColor)
                    .background(Color.secondary.opacity(0.1))
            }
        }
        .refreshable { viewModel?.performSmartSync() }
        .onAppear {
            if viewModel == nil {
                viewModel = LibraryViewModel(repo: container.repo, downloads: container.downloads)
                Task { await viewModel?.loadInitialData() }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if let vm = viewModel {
            VStack(spacing: 0) {
                // Status Text (Optional)
                if let status = vm.statusMessage {
                    Text(status).font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }
                
                stateBasedContent(vm: vm)
            }
        } else {
            ProgressView().padding(.top, 50)
        }
    }
    
    @ViewBuilder
    private func stateBasedContent(vm: LibraryViewModel) -> some View {
        if let error = vm.errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                .padding(.top, 40)
        } else if vm.isCurrentViewEmpty && !vm.isLoading {
            emptyStateView(vm: vm)
                .padding(.top, 40)
        } else {
            dataGrid(vm: vm)
        }
    }
    
    @ViewBuilder
    private func emptyStateView(vm: LibraryViewModel) -> some View {
        if vm.showDownloadedOnly {
            ContentUnavailableView(
                "No Downloaded \(vm.selectedScope.rawValue)",
                systemImage: "arrow.down.circle",
                description: Text("Try downloading some \(vm.selectedScope.rawValue.lowercased()) first.")
            )
        } else {
            ContentUnavailableView(
                "No \(vm.selectedScope.rawValue)",
                systemImage: "music.note.list"
            )
        }
    }
    
    @ViewBuilder
    private func dataGrid(vm: LibraryViewModel) -> some View {
        switch vm.selectedScope {
        case .albums: albumGrid(vm: vm)
        case .artists: artistList(vm: vm)
        case .genres: genreList(vm: vm)
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let vm = viewModel {
                Button { withAnimation { vm.showDownloadedOnly.toggle() } } label: {
                    Image(systemName: vm.showDownloadedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(vm.showDownloadedOnly ? Color.accentColor : Color.primary)
                }
            }
        }
        ToolbarItem(placement: .principal) {
            if let vm = viewModel {
                Picker("View", selection: Bindable(vm).selectedScope) {
                    ForEach(LibraryViewModel.LibraryScope.allCases) { scope in Text(scope.rawValue).tag(scope) }
                }
                .pickerStyle(.segmented).frame(width: 250)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { viewModel?.performSmartSync() } label: { Image(systemName: "arrow.clockwise") }
        }
    }
    
    // MARK: - Grids
    @ViewBuilder
    private func albumGrid(vm: LibraryViewModel) -> some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(vm.filteredAlbums, id: \.id) { album in
                NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                    VStack(alignment: .leading, spacing: 8) {
                        CoverArtView(coverArtId: album.coverArtId, size: 150)
                            .cornerRadius(12).shadow(radius: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title).font(.headline).lineLimit(1).foregroundStyle(.primary)
                            if let artistName = album.artist?.name {
                                Text(artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
        }.padding()
    }
    
    @ViewBuilder
    private func artistList(vm: LibraryViewModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(vm.filteredArtists, id: \.id) { artist in
                NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id)) {
                    HStack(spacing: 16) {
                        Image(systemName: "music.mic.circle.fill").font(.system(size: 40)).foregroundStyle(Color.accentColor.opacity(0.8))
                        Text(artist.name).font(.body).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }.padding(.horizontal).padding(.vertical, 12)
                }
                Divider().padding(.leading, 70)
            }
        }
    }
    
    @ViewBuilder
    private func genreList(vm: LibraryViewModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(vm.filteredGenres, id: \.name) { genre in
                NavigationLink(value: Router.Destination.genreDetail(genreName: genre.name)) {
                    HStack(spacing: 16) {
                        Image(systemName: "guitars.fill").font(.system(size: 30)).foregroundStyle(Color.accentColor.opacity(0.8)).frame(width: 40)
                        VStack(alignment: .leading) {
                            Text(genre.name).font(.body).foregroundStyle(.primary)
                            Text("\(genre.albumCount) albums • \(genre.songCount) songs").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }.padding(.horizontal).padding(.vertical, 12)
                }.buttonStyle(.plain)
                Divider().padding(.leading, 70)
            }
        }
    }
}

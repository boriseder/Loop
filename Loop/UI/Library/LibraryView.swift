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
    
    // Grid Layout for Albums
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            if let vm = viewModel {
                // Status Bar
                if let status = vm.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                
                // Error State
                if let error = vm.errorMessage {
                    ContentUnavailableView {
                        Label("Library Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await vm.loadInitialData() } }
                    }
                }
                // Empty State
                else if vm.filteredItems.isEmpty && !vm.isLoading {
                    ContentUnavailableView("No \(vm.selectedScope.rawValue)", systemImage: "music.note.list")
                }
                // Content
                else {
                    VStack(spacing: 0) {
                        switch vm.selectedScope {
                        case .albums:
                            albumGrid(vm: vm)
                        case .artists:
                            artistList(vm: vm)
                        }
                    }
                }
            } else {
                ProgressView().padding(.top, 50)
            }
        }
        .navigationTitle("Library")
        .searchable(text: Binding(
            get: { viewModel?.searchText ?? "" },
            set: { viewModel?.searchText = $0 }
        ), prompt: "Filter...")
        .toolbar {
            // Scope Selector
            ToolbarItem(placement: .principal) {
                if let vm = viewModel {
                    Picker("View", selection: Bindable(vm).selectedScope) {
                        ForEach(LibraryViewModel.LibraryScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel?.performSync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            viewModel?.performSync()
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LibraryViewModel(
                    repo: container.repo,
                    downloads: container.downloads
                )
                Task { await viewModel?.loadInitialData() }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func albumGrid(vm: LibraryViewModel) -> some View {
        LazyVGrid(columns: columns, spacing: 24) {
            // ✅ FIX: Explicitly use id: \.id for safety
            ForEach(vm.filteredItems as? [Album] ?? [], id: \.id) { album in
                NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                    VStack(alignment: .leading, spacing: 8) {
                        CoverArtView(coverArtId: album.coverArtId, size: 150)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            
                            if let artistName = album.artist?.name {
                                Text(artistName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func artistList(vm: LibraryViewModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // ✅ FIX: Explicitly use id: \.id
            ForEach(vm.filteredItems as? [Artist] ?? [], id: \.id) { artist in
                NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id)) {
                    HStack(spacing: 16) {
                        Image(systemName: "music.mic.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor.opacity(0.8))
                        
                        Text(artist.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                Divider().padding(.leading, 70)
            }
        }
    }
}

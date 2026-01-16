//
//  SearchView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct SearchView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: SearchViewModel?
    
    var body: some View {
        // ✅ FIX: Removed NavigationStack - use the parent's navigation context
        List {
            if let vm = viewModel {
                searchResults(for: vm)
            } else {
                ProgressView()
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text("Search", comment: "Navigation title"))
        .searchable(
            text: queryBinding,
            placement: .automatic,
            prompt: Text("Songs, Albums, Artists...", comment: "Search placeholder")
        )
        .searchScopes(scopeBinding) {
            ForEach(SearchViewModel.SearchScope.allCases) { scope in
                Text(scope.localizedName).tag(scope)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SearchViewModel(repo: container.repo)
            }
        }
    }
    
    // MARK: - Bindings
    private var queryBinding: Binding<String> {
        Binding(get: { viewModel?.query ?? "" }, set: { viewModel?.query = $0 })
    }
    
    private var scopeBinding: Binding<SearchViewModel.SearchScope> {
        Binding(get: { viewModel?.selectedScope ?? .all }, set: { viewModel?.selectedScope = $0 })
    }
    
    // MARK: - View Builders
    @ViewBuilder
    private func searchResults(for vm: SearchViewModel) -> some View {
        if vm.isLoading {
            HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
        }
        
        if let error = vm.errorMessage {
            Text(error).foregroundStyle(.red).font(.caption).listRowSeparator(.hidden)
        }
        
        // Results: Songs
        if !vm.displayedSongs.isEmpty {
            Section(header: Text("Songs", comment: "Section header")) {
                ForEach(vm.displayedSongs, id: \.id) { song in
                    Button {
                        Task {
                            await container.audio.setupPlayer(with: song.id, queue: vm.displayedSongs.map(\.id))
                        }
                    } label: {
                        HStack {
                            if let album = song.album {
                                CoverArtView(coverArtId: album.coverArtId, size: 40).cornerRadius(4)
                            }
                            VStack(alignment: .leading) {
                                Text(song.title).lineLimit(1)
                                Text(song.artist?.name ?? "Unknown").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        
        // Results: Albums
        if !vm.displayedAlbums.isEmpty {
            Section(header: Text("Albums", comment: "Section header")) {
                ForEach(vm.displayedAlbums, id: \.id) { album in
                    NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                        HStack {
                            CoverArtView(coverArtId: album.coverArtId, size: 40).cornerRadius(4)
                            Text(album.title).lineLimit(1)
                        }
                    }
                }
            }
        }
        
        // Results: Artists
        if !vm.displayedArtists.isEmpty {
            Section(header: Text("Artists", comment: "Section header")) {
                ForEach(vm.displayedArtists, id: \.id) { artist in
                    NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id)) {
                        Text(artist.name)
                    }
                }
            }
        }
    }
}

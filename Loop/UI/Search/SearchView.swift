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
        NavigationStack {
            ScrollView {
                if let vm = viewModel {
                    if vm.isLoading {
                        ProgressView().padding(.top, 50)
                    } else if vm.searchText.isEmpty {
                        ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Search your Navidrome server"))
                            .padding(.top, 50)
                    } else if vm.albums.isEmpty && vm.artists.isEmpty && vm.songs.isEmpty {
                        ContentUnavailableView.search(text: vm.searchText)
                            .padding(.top, 50)
                    } else {
                        resultsList(vm: vm)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ), prompt: "Artists, Albums, Songs...")
            .onSubmit(of: .search) {
                Task { await viewModel?.performSearch() }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = SearchViewModel(client: container.client, repo: container.repo)
                }
            }
        }
    }
    
    @ViewBuilder
    private func resultsList(vm: SearchViewModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            
            // Artists
            if !vm.artists.isEmpty {
                Text("Artists").font(.title2.bold()).padding(.horizontal).padding(.top, 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.artists, id: \.id) { artist in
                            NavigationLink(value: Router.Destination.artistDetail(artistId: artist.id)) {
                                VStack {
                                    Image(systemName: "music.mic.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                    Text(artist.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 80)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Albums
            if !vm.albums.isEmpty {
                Text("Albums").font(.title2.bold()).padding(.horizontal).padding(.top, 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.albums, id: \.id) { album in
                            NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                                VStack(alignment: .leading) {
                                    CoverArtView(coverArtId: album.coverArtId, size: 120)
                                        .cornerRadius(8)
                                    Text(album.title)
                                        .font(.caption)
                                        .bold()
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 120)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Songs
            if !vm.songs.isEmpty {
                Text("Songs").font(.title2.bold()).padding(.horizontal).padding(.top, 10)
                ForEach(vm.songs, id: \.id) { song in
                    HStack {
                        CoverArtView(coverArtId: song.album?.coverArtId, size: 40)
                            .cornerRadius(4)
                        VStack(alignment: .leading) {
                            Text(song.title).font(.body).lineLimit(1)
                            Text(song.artist?.name ?? "Unknown").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await container.audio.setupPlayer(with: song.id, queue: [song.id]) }
                        } label: {
                            Image(systemName: "play.circle").font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    Divider().padding(.leading, 60)
                }
            }
        }
        .padding(.bottom, 80)
    }
}

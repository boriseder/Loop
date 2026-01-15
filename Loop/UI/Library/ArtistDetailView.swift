//
//  ArtistDetailView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    @Environment(AppContainer.self) private var container
    @State private var viewModel: ArtistDetailViewModel?
    
    // Grid Layout
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(vm.artistName)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Albums Grid
                    if !vm.albums.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Albums", comment: "Section header")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 20) {
                                // ✅ FIX: Explicitly use id: \.id
                                ForEach(vm.albums, id: \.id) { album in
                                    NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                                        VStack(alignment: .leading) {
                                            CoverArtView(coverArtId: album.coverArtId, size: 150)
                                                .cornerRadius(12)
                                                .shadow(radius: 4)
                                            
                                            Text(album.title)
                                                .font(.subheadline)
                                                .bold()
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                            
                                            if let year = album.year {
                                                Text(String(year))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else if !vm.isLoading {
                        ContentUnavailableView("No Albums Found", systemImage: "opticaldisc")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = ArtistDetailViewModel(artistId: artistId, repo: container.repo)
                await viewModel?.load()
            }
        }
    }
}

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
    
    var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Header
                    HStack(spacing: 16) {
                        Image(systemName: "music.mic.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.accentColor.opacity(0.8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Artist")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            
                            // ✅ FIX: Access name via the optional artist object
                            Text(vm.artist?.name ?? "Loading...")
                                .font(.title)
                                .fontWeight(.bold)
                                .lineLimit(2)
                            
                            Text("\(vm.albums.count) Albums")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Divider().padding(.horizontal)
                    
                    // MARK: - Albums List
                    if vm.isLoading && vm.albums.isEmpty {
                        ProgressView().padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 24) {
                            ForEach(vm.albums, id: \.id) { album in
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
                                            
                                            Text(String(album.year ?? 0))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView().padding(.top, 50)
            }
        }
        .navigationTitle("") // Hide default title to use custom header
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = ArtistDetailViewModel(artistId: artistId, repo: container.repo)
            }
        }
        .task {
            await viewModel?.load()
        }
    }
}

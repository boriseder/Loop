//
//  ArtistDetailView.swift
//  Loop
//
//  FIXED: Uses MusicEnvironment, async operations
//

import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    
    @Environment(MusicEnvironment.self) private var music
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
                                        CoverImageView(coverId: album.coverArtId, size: 150)
                                            .cornerRadius(12)
                                            .shadow(radius: 4)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(album.title)
                                                .font(.headline)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = ArtistDetailViewModel(artistId: artistId, music: music)
            }
        }
        .task {
            await viewModel?.load()
        }
    }
}

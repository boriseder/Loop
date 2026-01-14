//
//  AlbumDetailView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    
    // ✅ FIX: Use Modern Injection
    @Environment(AppContainer.self) private var container
    
    @State private var viewModel: AlbumDetailViewModel?
    
    var body: some View {
        List {
            if let vm = viewModel {
                // Header
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            // ✅ NEW: Dynamic Cover Art
                            // We take the coverArtId from the album of the first song
                            if let firstSong = vm.songs.first, let album = firstSong.album {
                                CoverArtView(coverArtId: album.coverArtId, size: 140)
                                    .cornerRadius(12)
                                    .shadow(radius: 8)
                            } else {
                                // Loading state
                                CoverArtView(coverArtId: nil, size: 140)
                                    .cornerRadius(12)
                            }
                            
                            Text(vm.albumTitle)
                                .font(.title2).bold()
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                }
                // Songs
                ForEach(vm.songs) { song in
                    HStack {
                        Text("\(song.trackNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 25, alignment: .leading)
                        Text(song.title)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        container.audio.setupPlayer(with: song.id, queue: vm.getQueue())
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Initialize VM only when view loads
            if viewModel == nil {
                viewModel = AlbumDetailViewModel(repo: container.repo, albumId: albumId)
                await viewModel?.loadSongs()
            }
        }
        .navigationTitle(viewModel?.albumTitle ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

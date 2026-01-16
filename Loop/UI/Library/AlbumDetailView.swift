//
//  AlbumDetailView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    @Environment(AppContainer.self) private var container
    @State private var viewModel: AlbumDetailViewModel?
    
    var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(spacing: 20) {
                    
                    // MARK: - Header
                    VStack(spacing: 12) {
                        CoverArtView(coverArtId: vm.album?.coverArtId, size: 200)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                        
                        VStack(spacing: 4) {
                            Text(vm.album?.title ?? "Loading...")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            
                            Text(vm.album?.artist?.name ?? "Unknown Artist")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            if let year = vm.album?.year {
                                Text(String(year)).font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        
                        // Action Buttons
                        HStack(spacing: 20) {
                            Button {
                                if let first = vm.songs.first { vm.play(song: first) }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            
                            // Download Button
                            Button {
                                vm.toggleDownload()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 50, height: 50)
                                    
                                    switch vm.downloadState {
                                    case .idle:
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.primary)
                                            
                                    case .downloading:
                                        ProgressView()
                                            .tint(.primary)
                                            
                                    case .downloaded:
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .disabled(vm.downloadState == .downloading)
                        }
                    }
                    .padding(.top, 20)
                    
                    Divider().padding(.horizontal)
                    
                    // MARK: - Tracklist
                    LazyVStack(spacing: 0) {
                        ForEach(vm.songs) { song in
                            Button {
                                vm.play(song: song)
                            } label: {
                                HStack(spacing: 16) {
                                    Text(song.trackNumber > 0 ? "\(song.trackNumber)" : "-")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 25, alignment: .trailing)
                                    
                                    VStack(alignment: .leading) {
                                        Text(song.title).font(.body).lineLimit(1)
                                        if let artist = song.artist {
                                            Text(artist.name).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if container.downloads.isPinned(songId: song.id) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    
                                    Text(formatDuration(song.duration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 50)
                        }
                    }
                    .padding(.bottom, 100)
                }
            } else {
                ProgressView().padding(.top, 50)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                // ✅ FIX: Inject syncManager here
                viewModel = AlbumDetailViewModel(
                    albumId: albumId,
                    repo: container.repo,
                    syncManager: container.syncManager,
                    downloads: container.downloads,
                    player: container.audio
                )
            }
        }
        .task {
            await viewModel?.load()
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

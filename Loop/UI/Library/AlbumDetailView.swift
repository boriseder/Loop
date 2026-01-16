//
//  AlbumDetailView.swift
//  Loop
//
//  FIXED: Uses environment objects, async operations, skeleton loaders
//

import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    
    @Environment(MusicEnvironment.self) private var music
    @Environment(PlaybackEnvironment.self) private var playback
    @Environment(DownloadEnvironment.self) private var downloads
    
    @State private var viewModel: AlbumDetailViewModel?
    
    var body: some View {
        ScrollView {
            // ✅ Show skeleton during load
            if let vm = viewModel {
                if vm.album == nil && vm.songs.isEmpty {
                    AlbumDetailSkeleton()
                } else {
                    albumContent(vm)
                }
            } else {
                AlbumDetailSkeleton()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = AlbumDetailViewModel(
                    albumId: albumId,
                    music: music,
                    playback: playback,
                    downloads: downloads
                )
            }
        }
        .task {
            await viewModel?.load()
        }
    }
    
    @ViewBuilder
    private func albumContent(_ vm: AlbumDetailViewModel) -> some View {
        VStack(spacing: 20) {
            
            // MARK: - Header
            VStack(spacing: 12) {
                CoverImageView(coverId: vm.album?.coverArtId, size: 200)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                
                VStack(spacing: 4) {
                    Text(vm.album?.title ?? "Loading...")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(vm.album?.artistName ?? "Unknown Artist")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if let year = vm.album?.year {
                        Text(String(year)).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button {
                        if let first = vm.songs.first {
                            Task {
                                await vm.play(song: first)
                            }
                        }
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
                        Task {
                            await vm.toggleDownload()
                        }
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
                        Task {
                            await vm.play(song: song)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Text(song.trackNumber > 0 ? "\(song.trackNumber)" : "-")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 25, alignment: .trailing)
                            
                            VStack(alignment: .leading) {
                                Text(song.title).font(.body).lineLimit(1)
                                if let artist = song.artistName {
                                    Text(artist).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if downloads.isPinned(songId: song.id) {
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
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Cover Image Component

struct CoverImageView: View {
    let coverId: String?
    let size: Int
    
    @Environment(MusicEnvironment.self) private var music
    @State private var image: UIImage?
    
    var body: some View {
        let safeSize = CGFloat(max(50, size))
        
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder(size: safeSize)
            }
        }
        .frame(width: safeSize, height: safeSize)
        .background(Color.secondary.opacity(0.1))
        .task(id: coverId) {
            if let id = coverId {
                image = await music.getCoverImage(for: id, size: size * 2)
            }
        }
    }
    
    private func placeholder(size: CGFloat) -> some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}

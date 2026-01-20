import SwiftUI

struct AlbumDetailView: View {
    @State var vm: AlbumDetailViewModel
    let cache: CoverArtCache
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                if let album = vm.album {
                    VStack(spacing: 12) {
                        AlbumHeaderImage(coverId: album.coverArtId, cache: cache)
                        
                        Text(album.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(album.artistName ?? "Unknown Artist")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        // Controls
                        HStack(spacing: 20) {
                            // Play Button
                            Button {
                                Task {
                                    if let first = vm.songs.first {
                                        await vm.play(song: first)
                                    }
                                }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .disabled(vm.songs.isEmpty)
                            
                            // Download Button with State
                            DownloadButton(
                                isDownloading: vm.isDownloading,
                                isDownloaded: vm.isDownloaded(),
                                progress: vm.downloadProgress,
                                isEmpty: vm.songs.isEmpty,
                                onTap: {
                                    print("🔘 Download button tapped - isDownloading: \(vm.isDownloading), isDownloaded: \(vm.isDownloaded())")
                                    if vm.isDownloading {
                                        vm.cancelDownload()
                                    } else if vm.isDownloaded() {
                                        vm.showDeleteConfirmation = true
                                    } else {
                                        vm.downloadAlbum()
                                    }
                                }
                            )
                            .alert("Delete Downloads", isPresented: $vm.showDeleteConfirmation) {
                                Button("Cancel", role: .cancel) { }
                                Button("Delete", role: .destructive) {
                                    vm.deleteAlbum()
                                }
                            } message: {
                                Text("Are you sure you want to delete all downloaded songs from this album?")
                            }
                        }
                    }
                    .padding(.top)
                }
                
                // Tracklist
                LazyVStack(spacing: 0) {
                    ForEach(vm.songs) { song in
                        Button {
                            Task { await vm.play(song: song) }
                        } label: {
                            SongRow(
                                song: song,
                                isDownloaded: vm.isSongDownloaded(song.id),
                                isPlaying: vm.audio.currentSong?.id == song.id,
                                isCurrentlyPlaying: vm.audio.isPlaying && vm.audio.currentSong?.id == song.id
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .task { await vm.load() }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents

struct AlbumHeaderImage: View {
    let coverId: String?
    let cache: CoverArtCache
    
    var body: some View {
        AsyncCoverImage(coverId: coverId, size: 600, cache: cache)
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
    }
}

struct DownloadButton: View {
    let isDownloading: Bool
    let isDownloaded: Bool
    let progress: Double
    let isEmpty: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                
                if isDownloading {
                    // Show progress with percentage
                    ZStack {
                        CircularProgressView(progress: progress)
                            .frame(width: 34, height: 34)
                        
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                } else if isDownloaded {
                    // Downloaded - tap to delete
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.green)
                } else {
                    // Not downloaded - tap to download
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(.primary)
                }
            }
        }
        .disabled(isEmpty)
        .animation(.easeInOut(duration: 0.2), value: isDownloading)
        .animation(.easeInOut(duration: 0.2), value: isDownloaded)
    }
}

struct SongRow: View {
    let song: SongDTO
    let isDownloaded: Bool
    let isPlaying: Bool
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Track number badge or now playing indicator
            ZStack {
                if isCurrentlyPlaying {
                    // Animated now playing indicator
                    NowPlayingIndicator(isPlaying: isCurrentlyPlaying)
                } else {
                    Circle()
                        .fill(isPlaying ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Text("\(song.trackNumber)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                        .monospacedDigit()
                }
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                    .lineLimit(1)
                
                if let artist = song.artistName {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                }
                
                Text(formatDuration(song.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}

struct AsyncCoverImage: View {
    let coverId: String?
    let size: Int
    let cache: CoverArtCache
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.1)
                    .overlay(Image(systemName: "music.note"))
            }
        }
        .task(id: coverId) {
            if let coverId {
                image = await cache.image(for: coverId, size: size)
            }
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
        }
    }
}

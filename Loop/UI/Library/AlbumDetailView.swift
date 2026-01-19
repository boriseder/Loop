import SwiftUI

struct AlbumDetailView: View {
    @State var vm: AlbumDetailViewModel
    let cache: CoverArtCache // ✅ Added explicit dependency
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                if let album = vm.album {
                    VStack(spacing: 12) {
                        AlbumHeaderImage(coverId: album.coverArtId, cache: cache) // ✅ Pass cache
                        
                        Text(album.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(album.artistName ?? "Unknown Artist")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        // Controls
                        HStack(spacing: 20) {
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
                            
                            Button {
                                vm.downloadAlbum()
                            } label: {
                                ZStack {
                                    Circle().fill(.ultraThinMaterial).frame(width: 50, height: 50)
                                    if vm.isDownloading {
                                        ProgressView()
                                    } else if vm.isDownloaded() {
                                        Image(systemName: "checkmark").foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "arrow.down")
                                    }
                                }
                            }
                            .disabled(vm.isDownloading)
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
                            SongRow(song: song)
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
    let cache: CoverArtCache // ✅ Explicit dependency
    
    var body: some View {
        AsyncCoverImage(coverId: coverId, size: 600, cache: cache)
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
    }
}

struct SongRow: View {
    let song: SongDTO
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(song.trackNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 25, alignment: .trailing)
            
            VStack(alignment: .leading) {
                Text(song.title).font(.body).lineLimit(1)
            }
            
            Spacer()
            
            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
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
    let cache: CoverArtCache // ✅ Explicit dependency
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
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

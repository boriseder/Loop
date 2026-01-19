import SwiftUI

struct PlayerView: View {
    @Bindable var audio: AudioEngine
    let cache: CoverArtCache
    @Binding var isPresented: Bool
    
    @State private var coverImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                // Drag Handle
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top)
                
                // Cover Art
                let size = min(geometry.size.width, geometry.size.height) * 0.8
                Group {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.secondary.opacity(0.1)
                            .overlay(Image(systemName: "music.note"))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 20)
                
                // Meta
                VStack(spacing: 8) {
                    Text(audio.currentSong?.title ?? "Not Playing")
                        .font(.title2.bold())
                        .lineLimit(1)
                    
                    Text(audio.currentSong?.artistName ?? "")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                
                // Progress
                VStack(spacing: 8) {
                    // Slider Logic would go here (omitted for brevity, assume standard Slider binding)
                    ProgressView(value: audio.progress, total: audio.duration)
                        .tint(.primary)
                    
                    HStack {
                        Text(formatTime(audio.progress))
                        Spacer()
                        Text(formatTime(audio.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)
                
                // Controls
                HStack(spacing: 40) {
                    Button {
                        Task { await audio.skipToPrevious() }
                    } label: {
                        Image(systemName: "backward.fill").font(.system(size: 35))
                    }
                    
                    Button {
                        audio.togglePlayPause()
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                    }
                    
                    Button {
                        Task { await audio.skipToNext() }
                    } label: {
                        Image(systemName: "forward.fill").font(.system(size: 35))
                    }
                }
                .foregroundStyle(.primary)
                .padding(.bottom)
            }
        }
        .background(Material.regular)
        .task(id: audio.currentSong?.coverArtId) {
            if let id = audio.currentSong?.coverArtId {
                coverImage = await cache.image(for: id, size: 600)
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

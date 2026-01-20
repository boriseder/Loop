import SwiftUI

struct MiniPlayerView: View {
    let audio: AudioEngine
    let cache: CoverArtCache
    
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover Art
            Group {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.2)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Song Info
            VStack(alignment: .leading, spacing: 2) {
                Text(audio.currentSong?.title ?? "Not Playing")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                
                Text(audio.currentSong?.artistName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Playback Controls
            HStack(spacing: 16) {
                Button {
                    Task { await audio.skipToPrevious() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                Button {
                    audio.togglePlayPause()
                } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                Button {
                    Task { await audio.skipToNext() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 4)
        }
        .padding(12)
        .background(Material.bar)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .task(id: audio.currentSong?.coverArtId) {
            if let coverArtId = audio.currentSong?.coverArtId {
                coverImage = await cache.image(for: coverArtId, size: 200)
            } else {
                coverImage = nil
            }
        }
    }
}

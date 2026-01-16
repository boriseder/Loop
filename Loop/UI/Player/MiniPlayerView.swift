//
//  MiniPlayerView.swift
//  Loop
//
//  FIXED: Added prev/next buttons, better layout
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlaybackEnvironment.self) private var playback
    @Environment(MusicEnvironment.self) private var music
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover Art
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.2)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(playback.currentTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text(playback.currentArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // ✅ NEW: Playback Controls
            HStack(spacing: 8) {
                Button {
                    playback.skipToPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                
                Button {
                    if playback.isPlaying {
                        playback.pause()
                    } else {
                        playback.play()
                    }
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                
                Button {
                    playback.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.trailing, 4)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .task(id: playback.currentCoverId) {
            if let coverId = playback.currentCoverId {
                coverImage = await music.getCoverImage(for: coverId, size: 88)
            }
        }
    }
}

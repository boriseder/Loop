//
//  PlayerView.swift
//  Loop
//
//  FIXED: Uses PlaybackEnvironment and MusicEnvironment
//

import SwiftUI
import MediaPlayer

struct PlayerView: View {
    @Environment(PlaybackEnvironment.self) private var playback
    @Environment(MusicEnvironment.self) private var music
    @Binding var isPresented: Bool
    
    @State private var isDraggingSlider = false
    @State private var dragProgress: Double = 0.0
    @State private var coverImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // Drag Indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                
                // Cover Art
                let minDimension = min(geometry.size.width, geometry.size.height)
                let artSize = minDimension * 0.8
                
                Group {
                    if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.secondary.opacity(0.1)
                            Image(systemName: "music.note")
                                .font(.system(size: artSize * 0.3))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: artSize, height: artSize)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.bottom, 40)
                
                // Metadata
                VStack(spacing: 8) {
                    Text(playback.currentTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(playback.currentArtist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                
                Spacer()
                
                // Scrubber
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { isDraggingSlider ? dragProgress : playback.progress },
                        set: { newVal in
                            isDraggingSlider = true
                            dragProgress = newVal
                        }
                    ), in: 0...1) { editing in
                        if !editing {
                            let targetTime = dragProgress * playback.duration
                            playback.seek(to: targetTime)
                            isDraggingSlider = false
                        }
                    }
                    .tint(.primary)
                    
                    HStack {
                        Text(formatTime(isDraggingSlider ? dragProgress * playback.duration : playback.progress * playback.duration))
                        Spacer()
                        Text(formatTime(playback.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
                
                // Controls
                HStack(spacing: 50) {
                    Button {
                        playback.seek(to: 0)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 35))
                    }
                    
                    Button {
                        if playback.isPlaying {
                            playback.pause()
                        } else {
                            playback.play()
                        }
                    } label: {
                        Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 80))
                    }
                    
                    Button {
                        playback.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 35))
                    }
                }
                .foregroundStyle(.primary)
                .padding(.bottom, 50)
            }
            .frame(width: geometry.size.width)
        }
        .background(Material.regular)
        .task(id: playback.currentCoverId) {
            if let coverId = playback.currentCoverId {
                coverImage = await music.getCoverImage(for: coverId, size: 600)
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

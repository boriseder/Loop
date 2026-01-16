//
//  PlayerView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import MediaPlayer

struct PlayerView: View {
    @Environment(AppContainer.self) private var container
    @Binding var isPresented: Bool
    
    @State private var isDraggingSlider = false
    @State private var dragProgress: Double = 0.0
    
    var body: some View {
        let audio = container.audio
        
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // Drag Indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                
                // Cover Art
                // ✅ FIX: Safe geometry calculation
                let minDimension = min(geometry.size.width, geometry.size.height)
                let artSize = minDimension * 0.8 // 80% of width
                
                CoverArtView(coverArtId: audio.currentCoverId, size: Int(artSize * 2))
                    .frame(width: artSize, height: artSize)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.bottom, 40)
                
                // Metadata
                VStack(spacing: 8) {
                    Text(audio.currentTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(audio.currentArtist)
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
                        get: { isDraggingSlider ? dragProgress : audio.progress },
                        set: { newVal in
                            isDraggingSlider = true
                            dragProgress = newVal
                        }
                    ), in: 0...1) { editing in
                        if !editing {
                            let targetTime = dragProgress * audio.duration
                            container.audio.seek(to: targetTime)
                            isDraggingSlider = false
                        }
                    }
                    .tint(.primary)
                    
                    HStack {
                        Text(formatTime(isDraggingSlider ? dragProgress * audio.duration : audio.progress * audio.duration))
                        Spacer()
                        Text(formatTime(audio.duration))
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
                        container.audio.seek(to: 0)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 35))
                    }
                    
                    Button {
                        if audio.isPlaying {
                            container.audio.pause()
                        } else {
                            container.audio.play()
                        }
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 80))
                    }
                    
                    Button {
                        container.audio.skipToNext()
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
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

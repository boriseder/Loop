//
//  MiniPlayerView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        let audio = container.audio
        
        VStack(spacing: 0) {
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * audio.progress)
                }
            }
            .frame(height: 2)
            
            HStack(spacing: 12) {
                // ✅ Cover Art (Driven by AudioEngine state)
                CoverArtView(coverArtId: audio.currentCoverId, size: 48)
                    .cornerRadius(6)
                    // Force animation/reload when song changes
                    .id(audio.currentSongId)

                VStack(alignment: .leading) {
                    // ✅ Title & Artist (Driven by AudioEngine state)
                    Text(audio.currentTitle)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(1)
                    
                    Text(audio.currentArtist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Controls
                Button {
                    audio.isPlaying ? audio.pause() : audio.play()
                } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .padding(8)
                }
                
                Button {
                    audio.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .padding(8)
                }
            }
            .padding(12)
            .background(.thinMaterial)
        }
    }
}

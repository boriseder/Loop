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
        
        HStack(spacing: 12) {
            // Cover Art
            CoverArtView(coverArtId: audio.currentCoverId, size: 44)
                .cornerRadius(6)
            
            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(audio.currentTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text(audio.currentArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play/Pause Button
            Button {
                if audio.isPlaying {
                    container.audio.pause()
                } else {
                    container.audio.play()
                }
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .padding(.trailing, 8)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

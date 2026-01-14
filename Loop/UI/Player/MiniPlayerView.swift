//
//  MiniPlayerView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppContainer.self) private var container
    @State private var currentCoverArtId: String?
    
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
                // Cover Art
                CoverArtView(coverArtId: currentCoverArtId, size: 48)
                    .cornerRadius(6)
                    .id(currentCoverArtId) // Force redraw if ID changes

                VStack(alignment: .leading) {
                    Text(audio.currentSongId ?? String(localized: "Not Playing"))
                        .font(.subheadline)
                        .bold()
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
        // ✅ Debug Task
        .task(id: audio.currentSongId) {
            guard let songId = audio.currentSongId else {
                currentCoverArtId = nil
                return
            }
            
            print("🔍 MiniPlayer: Fetching cover for song \(songId)...")
            let artId = await container.repo.getCoverArtId(for: songId)
            
            if let artId {
                print("🎨 MiniPlayer: Received Art ID: \(artId)")
            } else {
                print("❌ MiniPlayer: Received NIL Art ID")
            }
            
            self.currentCoverArtId = artId
        }
    }
}

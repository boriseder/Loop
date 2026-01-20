//
//  NowPlayingIndicator.swift
//  Loop
//
//  Created by Boris Eder on 20.01.26.
//


import SwiftUI

/// Animated bars that indicate a song is currently playing
struct NowPlayingIndicator: View {
    let isPlaying: Bool
    @State private var heights: [CGFloat] = [0.3, 0.5, 0.7]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 12 * (isPlaying ? heights[index] : 0.3))
                    .animation(
                        isPlaying ? .easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.1) : .default,
                        value: heights[index]
                    )
            }
        }
        .frame(width: 10, height: 12)
        .onAppear {
            if isPlaying {
                startAnimating()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimating()
            }
        }
    }
    
    private func startAnimating() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard isPlaying else { return }
            withAnimation {
                heights = heights.map { _ in CGFloat.random(in: 0.3...1.0) }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NowPlayingIndicator(isPlaying: true)
        NowPlayingIndicator(isPlaying: false)
    }
    .padding()
}
//
//  CoverArtView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct CoverArtView: View {
    let coverArtId: String?
    let size: CGFloat
    
    @Environment(AppContainer.self) private var container
    @Environment(\.displayScale) private var scale
    
    // Internal State
    @State private var image: Image?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: coverArtId) { // ✅ Re-fetch if ID changes
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let coverArtId else {
            self.image = nil
            return
        }
        
        // ✅ 1. CHECK DISK FIRST (Offline Mode)
        // This was missing from your snippet, but essential for offline support!
        if let localURL = container.downloads.localCoverURL(for: coverArtId),
           let data = try? Data(contentsOf: localURL),
           let uiImage = UIImage(data: data) {
            self.image = Image(uiImage: uiImage)
            return
        }
        
        let pixelSize = Int(size * scale)
        guard let url = container.client.coverArtURL(id: coverArtId, size: pixelSize) else { return }
        
        // Avoid re-downloading if we already have the correct image
        if isLoading { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 2. Download from Network
            let data = try await container.client.downloadData(from: url)
            if let uiImage = UIImage(data: data) {
                self.image = Image(uiImage: uiImage)
            }
        } catch is CancellationError {
            // ✅ SILENCE: Task was cancelled by SwiftUI (user scrolled away)
        } catch let error as URLError where error.code == .cancelled {
            // ✅ SILENCE: Network request was cancelled
        } catch {
            print("❌ CoverArt Failed: \(error)")
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
            
            Image(systemName: "music.note")
                .resizable()
                .scaledToFit()
                .padding(size * 0.3)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}

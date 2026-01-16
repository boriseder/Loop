//
//  CoverArtView.swift
//  Loop
//
//  Using the new CoverArtCache system
//

import SwiftUI

struct CoverArtView: View {
    let coverArtId: String?
    let size: Int
    
    @Environment(AppContainer.self) private var container
    @State private var image: UIImage?
    
    var body: some View {
        let safeSize = CGFloat(max(50, size)) // Minimum 50 to prevent negative sizes
        
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder(size: safeSize)
            }
        }
        .frame(width: safeSize, height: safeSize)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: coverArtId) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let id = coverArtId else { return }
        
        self.image = await container.coverCache.getImage(for: id, size: size)
    }
    
    private func placeholder(size: CGFloat) -> some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}

//
//  CoverArtView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct CoverArtView: View {
    let coverArtId: String?
    let size: Int
    
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        let safeSize = CGFloat(max(0, size))
        
        Group {
            if let id = coverArtId {
                // 1. Try Local File (Offline Support)
                let localURL = container.downloads.localCoverURL(for: id)
                
                if let localImage = UIImage(contentsOfFile: localURL.path) {
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                // 2. Try Remote (Online Fallback)
                else if let url = container.client.coverArtURL(id: id, size: size) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholder(size: safeSize)
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholder(size: safeSize)
                        @unknown default:
                            placeholder(size: safeSize)
                        }
                    }
                } else {
                    placeholder(size: safeSize)
                }
            } else {
                placeholder(size: safeSize)
            }
        }
        .frame(width: safeSize, height: safeSize)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

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
    
    // ❌ DELETE THIS LINE IF YOU SEE IT:
    // @EnvironmentObject var container: AppContainer
    
    // ✅ USE THIS LINE INSTEAD:
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        if let id = coverArtId,
           let url = container.client.coverArtURL(id: id, size: size) {
            
            // Standard AsyncImage (No external dependencies)
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(width: CGFloat(size), height: CGFloat(size))
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
        } else {
            placeholder
                .frame(width: CGFloat(size), height: CGFloat(size))
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "music.note")
                .font(.system(size: CGFloat(size) * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}

//
//  AlbumCell.swift
//  Loop
//
//  Created by Boris Eder on 19.01.26.
//


import SwiftUI

struct AlbumCell: View {
    let album: AlbumDTO
    let cache: CoverArtCache
    @State private var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.2)
                        .overlay(Image(systemName: "music.note"))
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text(album.title)
                .font(.headline)
                .lineLimit(1)
            Text(album.artistName ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            if let id = album.coverArtId {
                image = await cache.image(for: id, size: 300)
            }
        }
    }
}
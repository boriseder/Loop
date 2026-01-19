//
//  ArtistRow.swift
//  Loop
//
//  Created by Boris Eder on 19.01.26.
//


import SwiftUI

struct ArtistRow: View {
    let artist: ArtistDTO
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.mic")
                        .foregroundStyle(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Text("^[\(artist.albumCount) Album](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}
//
//  GenreCell.swift
//  Loop
//
//  Created by Boris Eder on 19.01.26.
//


import SwiftUI

struct GenreCell: View {
    let genre: GenreDTO
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.1))
                    .aspectRatio(1.6, contentMode: .fit)
                
                Image(systemName: "guitars")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor.opacity(0.3))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
                Text(genre.name)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .padding(12)
            }
            
            Text("^[\(genre.albumCount) Album](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
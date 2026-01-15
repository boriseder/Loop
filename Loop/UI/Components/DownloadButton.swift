//
//  DownloadButton.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct DownloadButton: View {
    let song: Song
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        // Check if file exists locally
        let isDownloaded = container.downloads.isPinned(songId: song.id)
        // Check if currently in the active download queue
        let isDownloading = container.downloads.activeDownloads.contains(song.id)
        
        Button {
            if !isDownloaded && !isDownloading {
                Task {
                    await container.downloads.download(song: song)
                }
            }
        } label: {
            if isDownloading {
                ProgressView()
                    .controlSize(.small)
            } else if isDownloaded {
                Image(systemName: "arrow.down.circle.fill")
                    // ✅ FIX: Use 'Color.accentColor' instead of just '.accent'
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isDownloaded || isDownloading)
    }
}

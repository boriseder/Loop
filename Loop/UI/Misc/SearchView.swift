//
//  SearchView.swift
//  Loop
//
//  FIXED: Updated Router destination
//

import SwiftUI

struct SearchView: View {
    @Environment(MusicEnvironment.self) private var music
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    
    @State private var query = ""
    @State private var results = SearchResults()
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            List {
                if !results.albums.isEmpty {
                    Section("Albums") {
                        ForEach(results.albums) { album in
                            Button {
                                dismiss()
                                router.navigateToAlbum(album.id)
                            } label: {
                                Label(album.title, systemImage: "square.stack")
                            }
                        }
                    }
                }
                
                if !results.artists.isEmpty {
                    Section("Artists") {
                        ForEach(results.artists) { artist in
                            Button {
                                dismiss()
                                // ✅ UPDATE: Default showDownloadedOnly to false for search
                                router.navigateToArtist(artist.id, showDownloadedOnly: false)
                            } label: {
                                Label(artist.name, systemImage: "music.mic")
                            }
                        }
                    }
                }
                
                if !results.songs.isEmpty {
                    Section("Songs") {
                        ForEach(results.songs) { song in
                            Button {
                                dismiss()
                                router.navigateToAlbum(song.albumId)
                            } label: {
                                Label(song.title, systemImage: "music.note")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Albums, Artists, Songs")
            .onChange(of: query) { _, newValue in
                Task { await performSearch(newValue) }
            }
        }
    }
    
    private func performSearch(_ query: String) async {
        guard !query.isEmpty else {
            results = SearchResults()
            return
        }
        
        isSearching = true
        do {
            results = try await music.search(query: query)
        } catch {
            print("Search failed: \(error)")
        }
        isSearching = false
    }
}

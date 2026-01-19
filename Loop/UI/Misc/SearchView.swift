import SwiftUI

struct SearchView: View {
    let repo: MusicRepository
    let router: Router
    @Environment(\.dismiss) var dismiss
    
    @State private var query = ""
    @State private var results: (songs: [SongDTO], albums: [AlbumDTO], artists: [ArtistDTO]) = ([], [], [])
    @State private var isSearching = false
    
    // Task tracking for proper cancellation
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                if !results.songs.isEmpty {
                    Section("Songs") {
                        ForEach(results.songs) { song in
                            Button(song.title) {
                                router.navigateToAlbum(song.albumId)
                                dismiss()
                            }
                        }
                    }
                }
                
                if !results.albums.isEmpty {
                    Section("Albums") {
                        ForEach(results.albums) { album in
                            Button(album.title) {
                                router.navigateToAlbum(album.id)
                                dismiss()
                            }
                        }
                    }
                }
                
                if !results.artists.isEmpty {
                    Section("Artists") {
                        ForEach(results.artists) { artist in
                            Button(artist.name) {
                                router.navigateToArtist(artist.id)
                                dismiss()
                            }
                        }
                    }
                }
                
                if !isSearching && query.count > 1 && results.songs.isEmpty && results.albums.isEmpty && results.artists.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search music")
            .onChange(of: query) { _, newValue in
                performSearch(query: newValue)
            }
            .navigationTitle("Search")
        }
    }
    
    private func performSearch(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        // Clear results if query is too short
        guard query.count > 1 else {
            results = ([], [], [])
            isSearching = false
            return
        }
        
        // Start new search with debounce
        searchTask = Task {
            // Debounce: wait 300ms
            try? await Task.sleep(for: .milliseconds(300))
            
            // Check if cancelled during sleep
            guard !Task.isCancelled else { return }
            
            isSearching = true
            
            do {
                let searchResults = try await repo.search(query: query)
                
                // Check if cancelled after search
                guard !Task.isCancelled else { return }
                
                results = searchResults
                isSearching = false
                
            } catch {
                guard !Task.isCancelled else { return }
                
                results = ([], [], [])
                isSearching = false
            }
        }
    }
}

import SwiftUI

struct SearchView: View {
    let repo: MusicRepository
    let router: Router
    @Environment(\.dismiss) var dismiss
    
    @State private var query = ""
    @State private var results: (songs: [SongDTO], albums: [AlbumDTO], artists: [ArtistDTO]) = ([], [], [])
    
    var body: some View {
        NavigationStack {
            List {
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
                                // Navigate artist
                            }
                        }
                    }
                }
            }
            .searchable(text: $query)
            .onChange(of: query) { _, newValue in
                Task {
                    // Debounce manually or use library.
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    if newValue.count > 1 {
                        do {
                            results = try repo.search(query: newValue)
                        } catch {
                            print(error)
                        }
                    }
                }
            }
            .navigationTitle("Search")
        }
    }
}

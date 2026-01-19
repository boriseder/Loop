import SwiftUI

struct DownloadsView: View {
    let repo: MusicRepository
    let downloader: DownloadManager
    let cache: CoverArtCache
    
    @State private var downloadedAlbums: [AlbumDTO] = []
    
    var body: some View {
        ScrollView {
            if downloadedAlbums.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Downloaded albums will appear here"))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 24) {
                    ForEach(downloadedAlbums) { album in
                        NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                            AlbumCell(album: album, cache: cache)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Downloads")
        .task {
            await loadDownloads()
        }
    }
    
    private func loadDownloads() async {
        do {
            // Fetch all albums and filter by existence on disk
            let all = try repo.getAlbums(limit: 10000)
            // This filter is potentially slow, ideally we flag "downloaded" in DB
            // But for file-based truth, we check the downloader
            var list: [AlbumDTO] = []
            for album in all {
                // Check if directory contains songs or check song list
                // Simplified check:
                if let songs = try? repo.getSongs(for: album.id),
                   songs.contains(where: { downloader.isDownloaded(songId: $0.id) }) {
                    list.append(album)
                }
            }
            downloadedAlbums = list
        } catch {
            print("Error loading downloads")
        }
    }
}

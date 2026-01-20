import Foundation
import Observation

@Observable @MainActor
final class LibraryViewModel {
    enum State {
        case loading
        case content
        case empty
        case error(String)
    }
    
    var state: State = .loading
    var scope: LibraryScope = .albums {
        didSet {
            // Cancel previous load
            loadTask?.cancel()
            // Start new load
            loadTask = Task { await loadData() }
        }
    }
    
    var albums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
    var genres: [GenreDTO] = []
    
    enum LibraryScope { case albums, artists, genres }
    
    private let repo: MusicRepository
    private let syncManager: SyncManager
    private let downloader: DownloadManager
    private let filter: DownloadFilter
    
    // Task tracking for cancellation
    private var loadTask: Task<Void, Never>?
    
    init(repo: MusicRepository, syncManager: SyncManager, downloader: DownloadManager, filter: DownloadFilter) {
        self.repo = repo
        self.syncManager = syncManager
        self.downloader = downloader
        self.filter = filter
        
        // Observe filter changes
        Task {
            await observeFilterChanges()
        }
    }
    
    private func observeFilterChanges() async {
        // Reload data when filter changes
        // We'll trigger this manually from the view for now
    }
    
    func filterToggled() {
        loadTask?.cancel()
        loadTask = Task { await loadData() }
    }
    
    func loadData() async {
        // Only show loading spinner if we have no data
        if albums.isEmpty && artists.isEmpty && genres.isEmpty {
            state = .loading
        }
        
        do {
            switch scope {
            case .albums:
                let loaded = try await repo.getAlbums(limit: 1000)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Filter if needed
                if filter.showDownloadedOnly {
                    albums = await filterDownloadedAlbums(loaded)
                } else {
                    albums = loaded
                }
                
                state = albums.isEmpty ? .empty : .content
                
            case .artists:
                let loaded = try await repo.getArtists(limit: 1000)
                
                guard !Task.isCancelled else { return }
                
                // Filter if needed
                if filter.showDownloadedOnly {
                    artists = await filterArtistsWithDownloads(loaded)
                } else {
                    artists = loaded
                }
                
                state = artists.isEmpty ? .empty : .content
                
            case .genres:
                let loaded = try await repo.getGenres()
                
                guard !Task.isCancelled else { return }
                
                // Filter if needed
                if filter.showDownloadedOnly {
                    genres = await filterGenresWithDownloads(loaded)
                } else {
                    genres = loaded
                }
                
                state = genres.isEmpty ? .empty : .content
            }
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() {
        syncManager.startSmartSync(force: true)
        
        // Reload UI after short delay to let sync start
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await loadData()
        }
    }
    
    // MARK: - Filtering Logic
    
    private func filterDownloadedAlbums(_ albums: [AlbumDTO]) async -> [AlbumDTO] {
        var filtered: [AlbumDTO] = []
        
        for album in albums {
            if await isAlbumDownloaded(album.id) {
                filtered.append(album)
            }
        }
        
        print("🔍 Filtered albums: \(filtered.count)/\(albums.count)")
        return filtered
    }
    
    private func filterArtistsWithDownloads(_ artists: [ArtistDTO]) async -> [ArtistDTO] {
        var filtered: [ArtistDTO] = []
        
        for artist in artists {
            if await artistHasDownloads(artist.id) {
                filtered.append(artist)
            }
        }
        
        print("🔍 Filtered artists: \(filtered.count)/\(artists.count)")
        return filtered
    }
    
    private func filterGenresWithDownloads(_ genres: [GenreDTO]) async -> [GenreDTO] {
        var filtered: [GenreDTO] = []
        
        for genre in genres {
            if await genreHasDownloads(genre.name) {
                filtered.append(genre)
            }
        }
        
        print("🔍 Filtered genres: \(filtered.count)/\(genres.count)")
        return filtered
    }
    
    private func isAlbumDownloaded(_ albumId: String) async -> Bool {
        guard let songs = try? await repo.getSongs(for: albumId) else { return false }
        guard !songs.isEmpty else { return false }
        
        // Check if at least one song is downloaded
        return songs.contains { downloader.isDownloaded(songId: $0.id) }
    }
    
    private func artistHasDownloads(_ artistId: String) async -> Bool {
        guard let albums = try? await repo.getAlbums(forArtist: artistId) else { return false }
        
        for album in albums {
            if await isAlbumDownloaded(album.id) {
                return true
            }
        }
        
        return false
    }
    
    private func genreHasDownloads(_ genreName: String) async -> Bool {
        guard let albums = try? await repo.getAlbums(forGenre: genreName) else { return false }
        
        for album in albums {
            if await isAlbumDownloaded(album.id) {
                return true
            }
        }
        
        return false
    }
}

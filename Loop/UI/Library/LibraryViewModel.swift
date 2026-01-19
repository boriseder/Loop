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
        didSet { Task { await loadData() } }
    }
    
    var albums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
    var genres: [GenreDTO] = []
    
    enum LibraryScope { case albums, artists, genres }
    
    private let repo: MusicRepository
    private let syncManager: SyncManager
    
    init(repo: MusicRepository, syncManager: SyncManager) {
        self.repo = repo
        self.syncManager = syncManager
    }
    
    func loadData() async {
        // Optimistic loading - don't show spinner if we already have data
        if albums.isEmpty && artists.isEmpty { state = .loading }
        
        do {
            switch scope {
            case .albums:
                albums = try repo.getAlbums(limit: 500)
                state = albums.isEmpty ? .empty : .content
            case .artists:
                artists = try repo.getArtists(limit: 500)
                state = artists.isEmpty ? .empty : .content
            case .genres:
                genres = try repo.getGenres()
                state = genres.isEmpty ? .empty : .content
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() {
        syncManager.startSmartSync(force: true)
        Task {
            // Allow sync to start writing, then reload UI
            try? await Task.sleep(for: .seconds(1))
            await loadData()
        }
    }
}

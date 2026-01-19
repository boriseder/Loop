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
    
    // Task tracking for cancellation
    private var loadTask: Task<Void, Never>?
    
    init(repo: MusicRepository, syncManager: SyncManager) {
        self.repo = repo
        self.syncManager = syncManager
    }
    
    func loadData() async {
        // Only show loading spinner if we have no data
        if albums.isEmpty && artists.isEmpty && genres.isEmpty {
            state = .loading
        }
        
        do {
            switch scope {
            case .albums:
                let loaded = try await repo.getAlbums(limit: 500)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                albums = loaded
                state = loaded.isEmpty ? .empty : .content
                
            case .artists:
                let loaded = try await repo.getArtists(limit: 500)
                
                guard !Task.isCancelled else { return }
                
                artists = loaded
                state = loaded.isEmpty ? .empty : .content
                
            case .genres:
                let loaded = try await repo.getGenres()
                
                guard !Task.isCancelled else { return }
                
                genres = loaded
                state = loaded.isEmpty ? .empty : .content
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
}

import Foundation
import Observation

@Observable @MainActor
final class GenreDetailViewModel {
    var albums: [AlbumDTO] = []
    let genreName: String
    
    private let repo: MusicRepository
    
    init(genreName: String, repo: MusicRepository) {
        self.genreName = genreName
        self.repo = repo
    }
    
    func load() async {
        do {
            self.albums = try repo.getAlbums(forGenre: genreName)
        } catch {
            print("Error loading genre: \(error)")
        }
    }
}

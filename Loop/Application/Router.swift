import SwiftUI
import Observation

@Observable
final class Router {
    var path = NavigationPath()
    
    enum Destination: Hashable, Sendable {
        case albumDetail(albumId: String)
        case artistDetail(artistId: String, showDownloaded: Bool = false)
        case genreDetail(name: String, showDownloaded: Bool = false)
        case downloads
    }
    
    func navigateToAlbum(_ id: String) {
        path.append(Destination.albumDetail(albumId: id))
    }
    
    func navigateToArtist(_ id: String) {
        path.append(Destination.artistDetail(artistId: id))
    }
    
    func navigateToGenre(_ name: String) {
        path.append(Destination.genreDetail(name: name))
    }
    
    func navigateToDownloads() {
        path.append(Destination.downloads)
    }
}

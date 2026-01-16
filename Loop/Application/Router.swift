//
//  Router.swift
//  Loop
//
//  Navigation router - unchanged, already correct
//

import SwiftUI
import Observation

@Observable
final class Router {
    
    var path = NavigationPath()
    
    enum Destination: Hashable, Codable {
        case albumDetail(albumId: String)
        case artistDetail(artistId: String)
        case genreDetail(genreName: String)
    }
    
    func navigateToAlbum(_ id: String) {
        path.append(Destination.albumDetail(albumId: id))
    }
    
    func navigateToArtist(_ id: String) {
        path.append(Destination.artistDetail(artistId: id))
    }
    
    func navigateToGenre(_ name: String) {
        path.append(Destination.genreDetail(genreName: name))
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}

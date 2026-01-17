//
//  Router.swift
//  Loop
//
//  FIXED: Added downloads destination
//

import SwiftUI
import Observation

@Observable
final class Router {
    
    var path = NavigationPath()
    
    enum Destination: Hashable, Codable {
        case albumDetail(albumId: String)
        case artistDetail(artistId: String)
        case genreDetail(genreName: String, showDownloadedOnly: Bool)
        case downloads // ✅ NEW destination
    }
    
    func navigateToAlbum(_ id: String) {
        path.append(Destination.albumDetail(albumId: id))
    }
    
    func navigateToArtist(_ id: String) {
        path.append(Destination.artistDetail(artistId: id))
    }
    
    func navigateToGenre(_ name: String, showDownloadedOnly: Bool = false) {
        path.append(Destination.genreDetail(genreName: name, showDownloadedOnly: showDownloadedOnly))
    }
    
    // ✅ NEW navigation function
    func navigateToDownloads() {
        path.append(Destination.downloads)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}

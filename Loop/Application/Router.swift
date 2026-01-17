//
//  Router.swift
//  Loop
//
//  FIXED: Added showDownloadedOnly to Artist destination
//

import SwiftUI
import Observation

@Observable
final class Router {
    
    var path = NavigationPath()
    
    enum Destination: Hashable, Codable {
        case albumDetail(albumId: String)
        // ✅ UPDATE: Carry filter state
        case artistDetail(artistId: String, showDownloadedOnly: Bool)
        case genreDetail(genreName: String, showDownloadedOnly: Bool)
        case downloads
    }
    
    func navigateToAlbum(_ id: String) {
        path.append(Destination.albumDetail(albumId: id))
    }
    
    // ✅ UPDATE: Default to false
    func navigateToArtist(_ id: String, showDownloadedOnly: Bool = false) {
        path.append(Destination.artistDetail(artistId: id, showDownloadedOnly: showDownloadedOnly))
    }
    
    func navigateToGenre(_ name: String, showDownloadedOnly: Bool = false) {
        path.append(Destination.genreDetail(genreName: name, showDownloadedOnly: showDownloadedOnly))
    }
    
    func navigateToDownloads() {
        path.append(Destination.downloads)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}

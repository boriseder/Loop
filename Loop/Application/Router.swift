//
//  Router.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
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
    
    // ✅ NOTE: We've moved the view builder to ContentView in LoopApp.swift
    // This ensures views are created in a context where @Environment is available
    // You can delete this method or keep it for reference
    @ViewBuilder
    func view(for destination: Destination) -> some View {
        switch destination {
        case .albumDetail(let id):
            AlbumDetailView(albumId: id)
        case .artistDetail(let id):
            ArtistDetailView(artistId: id)
        case .genreDetail(let name):
            GenreDetailView(genreName: name)
        }
    }
}

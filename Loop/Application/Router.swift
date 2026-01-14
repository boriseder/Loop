//
//  Router.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI
import Observation

@Observable @MainActor
final class Router {
    var path = NavigationPath()
    
    enum Destination: Hashable {
        case albumDetail(albumId: String)
        case artistDetail(artistId: String)
        case player // Full screen player
        case settings
    }
    
    func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    func navigateBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func navigateToRoot() {
        path = NavigationPath()
    }
}

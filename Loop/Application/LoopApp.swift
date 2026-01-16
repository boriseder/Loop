//
//  LoopApp.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

@main
struct LoopApp: App {
    @State private var container = AppContainer()
    @State private var isPlayerPresented = false
    
    var body: some Scene {
        WindowGroup {
            @Bindable var router = container.router
            
            NavigationStack(path: $router.path) {
                LibraryView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            // ✅ FIX: Overlay attached to Stack (inside the Environment scope)
            .overlay(alignment: .bottom) {
                if container.audio.currentSongId != nil {
                    MiniPlayerView()
                        .padding(.bottom, 20)
                        .padding(.horizontal, 12)
                        .onTapGesture {
                            isPlayerPresented = true
                        }
                        .transition(.move(edge: .bottom))
                }
            }
            // ✅ FIX: Sheet attached to Stack (inside the Environment scope)
            .sheet(isPresented: $isPlayerPresented) {
                PlayerView(isPresented: $isPlayerPresented)
                    .presentationDragIndicator(.visible)
            }
            // ✅ FIX: Environment applied LAST so it injects into Stack + Overlay + Sheet
            .environment(container)
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: Router.Destination) -> some View {
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

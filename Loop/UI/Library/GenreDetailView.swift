//
//  GenreDetailView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct GenreDetailView: View {
    let genreName: String
    @Environment(AppContainer.self) private var container
    @State private var viewModel: GenreDetailViewModel?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    VStack(spacing: 12) {
                        // ✅ FIX: Changed to a valid SF Symbol
                        Image(systemName: "guitars.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor.gradient)
                            .shadow(radius: 5)
                        
                        Text(vm.genreName)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        
                        Text("\(vm.albums.count) Albums")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    Divider().padding(.horizontal)
                    
                    // MARK: - Album Grid
                    if vm.albums.isEmpty && !vm.isLoading {
                        ContentUnavailableView("No Albums", systemImage: "music.note.list", description: Text("No albums found for this genre."))
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(vm.albums, id: \.id) { album in
                                NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        CoverArtView(coverArtId: album.coverArtId, size: 150)
                                            .cornerRadius(12)
                                            .shadow(radius: 4)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(album.title)
                                                .font(.headline)
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                            
                                            Text(album.artist?.name ?? "Unknown")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView().padding(.top, 50)
            }
        }
        .navigationTitle(genreName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = GenreDetailViewModel(genreName: genreName, repo: container.repo)
                Task { await viewModel?.load() }
            }
        }
    }
}

import SwiftUI

struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: LibraryViewModel?
    
    var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    ForEach(vm.albums) { album in
                        Button {
                            container.router.navigate(to: .albumDetail(albumId: album.id))
                        } label: {
                            HStack {
                                Image(systemName: "music.note")
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                                VStack(alignment: .leading) {
                                    Text(album.title).font(.headline)
                                    Text(album.artist?.name ?? "Unknown").font(.caption)
                                }
                            }
                        }
                    }
                }
                .refreshable { await vm.performSync() }
                .task { await vm.loadInitialData() }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LibraryViewModel(repo: container.repo)
            }
        }
        .navigationTitle("Albums")
    }
}

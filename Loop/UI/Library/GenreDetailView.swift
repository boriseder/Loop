import SwiftUI

struct GenreDetailView: View {
    @State var vm: GenreDetailViewModel
    let container: AppContainer
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Image(systemName: "guitars.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top)
                
                Text(vm.genreName)
                    .font(.largeTitle.bold())
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 24) {
                    ForEach(vm.albums) { album in
                        NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                            AlbumCell(album: album, cache: container.coverCache)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .task { await vm.load() }
    }
}

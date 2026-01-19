import SwiftUI

struct ArtistDetailView: View {
    @State var vm: ArtistDetailViewModel
    let container: AppContainer // Needed to pass to children
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "music.mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                    
                    VStack(alignment: .leading) {
                        Text(vm.artist?.name ?? "Loading...")
                            .font(.title.bold())
                        Text("\(vm.albums.count) Albums")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                
                // Albums Grid
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

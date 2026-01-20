import Foundation

struct AlbumDTO: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artistId: String
    let artistName: String?
    let coverArtId: String?
    let year: Int?
    let genre: String?
    
    nonisolated init(from entity: Album) {
        self.id = entity.id
        self.title = entity.title
        self.artistId = entity.artistId
        self.artistName = entity.artist?.name
        self.coverArtId = entity.coverArtId
        self.year = entity.year
        self.genre = entity.genre
    }
}

struct ArtistDTO: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let albumCount: Int
    
    nonisolated init(from entity: Artist) {
        self.id = entity.id
        self.name = entity.name
        self.albumCount = entity.albums.count
    }
}

struct SongDTO: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let trackNumber: Int
    let duration: TimeInterval
    let path: String
    let albumId: String
    let artistId: String
    let artistName: String?
    let albumTitle: String?
    let coverArtId: String?
    
    nonisolated init(from entity: Song) {
        self.id = entity.id
        self.title = entity.title
        self.trackNumber = entity.trackNumber
        self.duration = entity.duration
        self.path = entity.path
        self.albumId = entity.albumId
        self.artistId = entity.artistId
        self.artistName = entity.artist?.name
        self.albumTitle = entity.album?.title
        self.coverArtId = entity.album?.coverArtId
    }
}

struct GenreDTO: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let songCount: Int
    let albumCount: Int
    
    nonisolated init(from entity: Genre) {
        self.name = entity.name
        self.songCount = entity.songCount
        self.albumCount = entity.albumCount
    }
}

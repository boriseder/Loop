import SwiftData

@Model
final class Album {
    @Attribute(.unique) var id: String
    var title: String
    var coverArtId: String?
    var year: Int?
    var artistId: String
    
    @Relationship(deleteRule: .cascade, inverse: \Song.album)
    var songs: [Song]?
    
    var artist: Artist?
    
    init(id: String, title: String, artistId: String, coverArtId: String? = nil, year: Int? = nil) {
        self.id = id
        self.title = title
        self.artistId = artistId
        self.coverArtId = coverArtId
        self.year = year
    }
}

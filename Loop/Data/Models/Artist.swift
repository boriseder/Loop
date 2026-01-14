import SwiftData

@Model
final class Artist {
    @Attribute(.unique) var id: String
    var name: String
    
    @Relationship(deleteRule: .cascade, inverse: \Album.artist)
    var albums: [Album]?
    
    @Relationship(deleteRule: .cascade, inverse: \Song.artist)
    var songs: [Song]?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

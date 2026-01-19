import Foundation
import SwiftData

// MARK: - Song
@Model
final class Song {
    @Attribute(.unique) var id: String
    var title: String
    var trackNumber: Int
    var duration: TimeInterval
    var path: String
    
    var artistId: String
    var albumId: String
    
    @Relationship(inverse: \Album.songs)
    var album: Album?
    
    @Relationship(inverse: \Artist.songs)
    var artist: Artist?
    
    init(id: String, title: String, trackNumber: Int, duration: TimeInterval, path: String, artistId: String, albumId: String) {
        self.id = id
        self.title = title
        self.trackNumber = trackNumber
        self.duration = duration
        self.path = path
        self.artistId = artistId
        self.albumId = albumId
    }
}

// MARK: - Album
@Model
final class Album {
    @Attribute(.unique) var id: String
    var title: String
    var artistId: String
    var coverArtId: String?
    var year: Int?
    var genre: String?
    
    @Relationship(deleteRule: .cascade)
    var songs: [Song] = []
    
    @Relationship(inverse: \Artist.albums)
    var artist: Artist?
    
    init(id: String, title: String, artistId: String, coverArtId: String?, year: Int?, genre: String? = nil) {
        self.id = id
        self.title = title
        self.artistId = artistId
        self.coverArtId = coverArtId
        self.year = year
        self.genre = genre
    }
}

// MARK: - Artist
@Model
final class Artist {
    @Attribute(.unique) var id: String
    var name: String
    
    @Relationship(deleteRule: .cascade)
    var albums: [Album] = []
    
    @Relationship(deleteRule: .cascade)
    var songs: [Song] = []
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Genre
@Model
final class Genre {
    @Attribute(.unique) var name: String
    var albumCount: Int
    var songCount: Int
    
    init(name: String, albumCount: Int, songCount: Int) {
        self.name = name
        self.albumCount = albumCount
        self.songCount = songCount
    }
}

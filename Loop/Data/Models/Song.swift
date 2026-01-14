import SwiftData
import Foundation

@Model
final class Song {
    @Attribute(.unique) var id: String
    var title: String
    var trackNumber: Int
    var duration: TimeInterval
    var path: String
    
    var artistId: String
    var albumId: String
    
    var album: Album?
    var artist: Artist?
    
    var dateAdded: Date
    var isPinned: Bool = false
    
    init(id: String, title: String, trackNumber: Int, duration: TimeInterval, path: String, artistId: String, albumId: String) {
        self.id = id
        self.title = title
        self.trackNumber = trackNumber
        self.duration = duration
        self.path = path
        self.artistId = artistId
        self.albumId = albumId
        self.dateAdded = Date()
    }
}

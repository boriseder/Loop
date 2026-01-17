//
//  DTOs.swift
//  Loop
//
//  Fixed: SongDTO now includes 'albumTitle' for Control Center display
//

import Foundation
import SwiftData

// MARK: - Album DTO
struct AlbumDTO: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artistId: String
    let artistName: String?
    let coverArtId: String?
    let year: Int?
    let genre: String?
    
    init(from entity: Album) {
        self.id = entity.id
        self.title = entity.title
        self.artistId = entity.artistId
        self.artistName = entity.artist?.name
        self.coverArtId = entity.coverArtId
        self.year = entity.year
        self.genre = entity.genre
    }
}

// MARK: - Artist DTO
struct ArtistDTO: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let albumCount: Int
    
    init(from entity: Artist) {
        self.id = entity.id
        self.name = entity.name
        self.albumCount = entity.albums.count
    }
}

// MARK: - Song DTO
struct SongDTO: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let trackNumber: Int
    let duration: TimeInterval
    let path: String
    let albumId: String
    let artistId: String
    
    // ✅ Flattened Properties (Optimized for UI & Player)
    let artistName: String?
    let albumTitle: String? // Added for Lock Screen
    let coverArtId: String?
    
    init(from entity: Song) {
        self.id = entity.id
        self.title = entity.title
        self.trackNumber = entity.trackNumber
        self.duration = entity.duration
        self.path = entity.path
        self.albumId = entity.albumId
        self.artistId = entity.artistId
        
        // Flatten relationships immediately
        self.artistName = entity.artist?.name
        self.albumTitle = entity.album?.title
        self.coverArtId = entity.album?.coverArtId
    }
}

// MARK: - Genre DTO
struct GenreDTO: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let songCount: Int
    let albumCount: Int
    
    init(from entity: Genre) {
        self.name = entity.name
        self.songCount = entity.songCount
        self.albumCount = entity.albumCount
    }
}

// MARK: - Search Results
struct SearchResults: Sendable {
    var songs: [SongDTO] = []
    var albums: [AlbumDTO] = []
    var artists: [ArtistDTO] = []
}

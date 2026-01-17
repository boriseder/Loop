//
//  SubsonicResponse.swift
//  Loop
//
//  Fixed: Restored SubsonicPingResponse and all other response wrappers.
//

import Foundation

// MARK: - Root Response Wrappers

struct SubsonicResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicWrapper: Decodable, Sendable {
    let status: String
    let version: String
    let type: String?
    let serverVersion: String?
    let error: RemoteError?
    
    // Lists
    let albumList2: RemoteAlbumList?
    let searchResult3: RemoteSearchResult?
    let indexes: RemoteIndexList? // Used for Smart Sync
    
    // Details
    let album: RemoteAlbumDetail?
    let artist: RemoteArtist?
    let genres: RemoteGenres?
    let song: RemoteSong?
}

struct RemoteError: Decodable, Sendable {
    let code: Int
    let message: String
}

// MARK: - Specific Response Types
// These are required because the top-level key is always "subsonic-response",
// but we define them separately to clarify intent at the call site.

struct SubsonicPingResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGetAlbumResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGetArtistResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGenresResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGetSongResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicSearchResponse: Decodable, Sendable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

// MARK: - Data Entities for 'getIndexes' (Smart Sync)

struct RemoteIndexList: Decodable, Sendable {
    let lastModified: Int64?
    let index: [RemoteIndex]?
}

struct RemoteIndex: Decodable, Sendable {
    let name: String
    let artist: [RemoteArtist]?
}

// MARK: - Other Data Entities

struct RemoteAlbumList: Decodable, Sendable {
    let album: [RemoteAlbum]?
}

struct RemoteSearchResult: Decodable, Sendable {
    let song: [RemoteSong]?
    let album: [RemoteAlbum]?
    let artist: [RemoteArtist]?
}

struct RemoteAlbum: Decodable, Sendable {
    let id: String
    let name: String
    let artist: String
    let artistId: String
    let coverArt: String?
    let year: Int?
    let genre: String?
    let duration: Int?
    let songCount: Int?
}

struct RemoteAlbumDetail: Decodable, Sendable {
    let id: String
    let name: String
    let artist: String
    let artistId: String
    let coverArt: String?
    let year: Int?
    let genre: String?
    let song: [RemoteSong]?
}

struct RemoteSong: Decodable, Sendable {
    let id: String
    let title: String
    let album: String?
    let artist: String?
    let track: Int?
    let year: Int?
    let genre: String?
    let coverArt: String?
    let duration: Int?
    let path: String?
    let contentType: String?
    let size: Int64?
}

struct RemoteArtist: Decodable, Sendable {
    let id: String
    let name: String
    let coverArt: String?
    let albumCount: Int?
    let album: [RemoteAlbum]?
}

struct RemoteGenres: Decodable, Sendable {
    let genre: [RemoteGenre]?
}

struct RemoteGenre: Decodable, Sendable {
    let value: String
    let songCount: Int
    let albumCount: Int
}

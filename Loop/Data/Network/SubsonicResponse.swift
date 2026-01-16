//
//  SubsonicResponse.swift
//  Loop
//
//  CRITICAL: No @MainActor isolation - pure Sendable data types
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
    let albumList2: RemoteAlbumList?
    let album: RemoteAlbumDetail?
    let artist: RemoteArtist?
    let genres: RemoteGenres?
    let song: RemoteSong?
    let searchResult3: RemoteSearchResult?
    let error: RemoteError?
}

struct RemoteError: Decodable, Sendable {
    let code: Int
    let message: String
}

// MARK: - Specific Response Types

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

// MARK: - Data Entities

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

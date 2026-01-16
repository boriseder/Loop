//
//  SubsonicModels.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation

// MARK: - Root Response Wrappers

struct SubsonicResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicWrapper: Decodable {
    let status: String
    let version: String
    let albumList2: RemoteAlbumList?
    let album: RemoteAlbumDetail?
    let artist: RemoteArtist?
    let genres: RemoteGenres?
    let song: RemoteSong?
    let searchResult3: RemoteSearchResult? // ✅ Added for Search
    let error: RemoteError?
}

struct RemoteError: Decodable {
    let code: Int
    let message: String
}

// MARK: - Specific Response Types (Helpers for generics)

struct SubsonicPingResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGetAlbumResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGetArtistResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGenresResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

struct SubsonicGetSongResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

// ✅ Added Search Response
struct SubsonicSearchResponse: Decodable {
    let subsonicResponse: SubsonicWrapper
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

// MARK: - Data Entities

struct RemoteAlbumList: Decodable {
    let album: [RemoteAlbum]?
}

struct RemoteSearchResult: Decodable {
    let song: [RemoteSong]?
    let album: [RemoteAlbum]?
    let artist: [RemoteArtist]?
}

struct RemoteAlbum: Decodable {
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

struct RemoteAlbumDetail: Decodable {
    let id: String
    let name: String
    let artist: String
    let artistId: String
    let coverArt: String?
    let year: Int?
    let genre: String?
    let song: [RemoteSong]?
}

struct RemoteSong: Decodable {
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

struct RemoteArtist: Decodable {
    let id: String
    let name: String
    let coverArt: String?
    let albumCount: Int?
    let album: [RemoteAlbum]?
}

struct RemoteGenres: Decodable {
    let genre: [RemoteGenre]?
}

struct RemoteGenre: Decodable {
    let value: String
    let songCount: Int
    let albumCount: Int
}

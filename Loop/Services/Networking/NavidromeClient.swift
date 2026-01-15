//
//  NavidromeClient.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import OSLog
import CryptoKit

// MARK: - 1. Safe DTO Definitions

// --- Search DTOs ---
nonisolated struct SubsonicSearchResponse: Decodable, Sendable {
    let subsonicResponse: SearchResponseBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct SearchResponseBody: Decodable, Sendable {
    let searchResult3: SearchResult3?
}

nonisolated struct SearchResult3: Decodable, Sendable {
    let song: [RemoteSong]?
    let album: [RemoteAlbum]?
    let artist: [RemoteArtist]?
}

nonisolated struct RemoteArtist: Decodable, Sendable {
    let id: String
    let name: String
    let albumCount: Int?
}

// --- Artist Detail DTOs ---
nonisolated struct SubsonicGetArtistResponse: Decodable, Sendable {
    let subsonicResponse: GetArtistBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct GetArtistBody: Decodable, Sendable {
    let artist: RemoteArtistDetail?
}

nonisolated struct RemoteArtistDetail: Decodable, Sendable {
    let id: String
    let name: String
    let album: [RemoteAlbum]?
}

// --- Song Detail DTO (New) ---
nonisolated struct SubsonicGetSongResponse: Decodable, Sendable {
    let subsonicResponse: GetSongBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct GetSongBody: Decodable, Sendable {
    let song: RemoteSong?
}

// -------------------

nonisolated struct SubsonicResponse: Decodable, Sendable {
    let subsonicResponse: ResponseBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct ResponseBody: Decodable, Sendable {
    let albumList2: AlbumList?
}

nonisolated struct AlbumList: Decodable, Sendable {
    let album: [RemoteAlbum]?
}

nonisolated struct RemoteAlbum: Decodable, Sendable {
    let id: String
    let name: String
    let artist: String
    let artistId: String
    let coverArt: String?
    let year: Int?
}

// MARK: - Album Details DTOs
nonisolated struct SubsonicGetAlbumResponse: Decodable, Sendable {
    let subsonicResponse: GetAlbumBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct GetAlbumBody: Decodable, Sendable {
    let album: RemoteAlbumDetails?
}

nonisolated struct RemoteAlbumDetails: Decodable, Sendable {
    let id: String
    let name: String
    let artist: String
    let artistId: String
    let coverArt: String?
    let year: Int?
    let song: [RemoteSong]?
}

nonisolated struct RemoteSong: Decodable, Sendable {
    let id: String
    let title: String
    let track: Int?
    let duration: Int?
    let path: String?
    
    // Search & Detail fields
    let artist: String?
    let album: String?
    let coverArt: String?
    
    // ✅ ADDED: Required for linking orphaned songs to albums
    let albumId: String?
}

// MARK: - 2. The Client Actor

actor NavidromeClient: NSObject {
    
    // MARK: - Configuration
    private let baseURL: URL
    private var session: URLSession!
    private let logger = Logger(subsystem: "com.loopapp", category: "NavidromeClient")
    
    // Credentials
    private let username: String
    private let salt: String
    private let token: String
    
    // MARK: - Initialization
    init(baseURL: URL = URL(string: "http://192.168.0.40:4533")!,
         username: String = "boris",
         password: String = "Beaver-4600!",
         salt: String = String.randomSalt()) {
        
        self.baseURL = baseURL
        self.username = username
        self.salt = salt
        self.token = NavidromeClient.generateToken(password: password, salt: salt)
        
        super.init()
        
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: nil
        )
        
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 300
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        logger.info("✅ NavidromeClient initialized for user: \(username)")
    }
    
    // MARK: - Fetching
    
    nonisolated func streamURL(for songId: String) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.path = "/rest/stream"
        components?.queryItems = defaultQueryItems + [URLQueryItem(name: "id", value: songId)]
        return components?.url
    }
    
    nonisolated func coverArtURL(id: String, size: Int = 300) -> URL? {
        return buildURL(endpoint: "getCoverArt", params: [
            "id": id,
            "size": String(size)
        ])
    }
    
    // MARK: - Search
    func search(query: String) async throws -> ([RemoteSong], [RemoteAlbum], [RemoteArtist]) {
        let params: [String: String] = [
            "query": query,
            "songCount": "20",
            "albumCount": "10",
            "artistCount": "10"
        ]
        
        guard let url = buildURL(endpoint: "search3", params: params) else {
            throw URLError(.badURL)
        }
        
        let response: SubsonicSearchResponse = try await fetch(url: url)
        let result = response.subsonicResponse.searchResult3
        
        return (result?.song ?? [], result?.album ?? [], result?.artist ?? [])
    }
    
    // MARK: - Artist Details
    func fetchArtist(id: String) async throws -> RemoteArtistDetail? {
        let response: SubsonicGetArtistResponse = try await fetch("getArtist", params: ["id": id])
        return response.subsonicResponse.artist
    }
    
    // MARK: - Song Details (New)
    func fetchSong(id: String) async throws -> RemoteSong? {
        let response: SubsonicGetSongResponse = try await fetch("getSong", params: ["id": id])
        return response.subsonicResponse.song
    }
    
    // Standard fetch with endpoint string
    func fetch<T: Decodable & Sendable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw URLError(.badURL)
        }
        return try await fetch(url: url)
    }
    
    // Generic fetch with raw URL
    func fetch<T: Decodable & Sendable>(url: URL) async throws -> T {
        logger.debug("Fetching URL: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            logger.error("HTTP Error: \(response)")
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
    
    // MARK: - Helpers
    
    private nonisolated var defaultQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "iOSClient"),
            URLQueryItem(name: "f", value: "json")
        ]
    }
    
    private nonisolated func buildURL(endpoint: String, params: [String: String]) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.path = "/rest/\(endpoint)"
        
        var queryItems = defaultQueryItems
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    // MARK: - Crypto Helper
    private static func generateToken(password: String, salt: String) -> String {
        let input = password + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - URLSessionDelegate
extension NavidromeClient: URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

private extension String {
    nonisolated static func randomSalt(length: Int = 6) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

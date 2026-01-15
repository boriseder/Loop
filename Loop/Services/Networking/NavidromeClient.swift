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

// --- Song Detail DTO ---
nonisolated struct SubsonicGetSongResponse: Decodable, Sendable {
    let subsonicResponse: GetSongBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct GetSongBody: Decodable, Sendable {
    let song: RemoteSong?
}

// --- Genre DTOs (Fixed for Single vs Array) ---
nonisolated struct SubsonicGetGenresResponse: Decodable, Sendable {
    let subsonicResponse: GetGenresBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated struct GetGenresBody: Decodable, Sendable {
    let genres: GenresContainer?
}

// ✅ FIX: Custom decoding to handle Array vs Single Object
nonisolated struct GenresContainer: Decodable, Sendable {
    let genre: [RemoteGenre]
    
    enum CodingKeys: String, CodingKey {
        case genre
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try decoding as Array first
        if let list = try? container.decode([RemoteGenre].self, forKey: .genre) {
            self.genre = list
        }
        // Fallback: Try decoding as Single Object
        else if let single = try? container.decode(RemoteGenre.self, forKey: .genre) {
            self.genre = [single]
        }
        // Fallback: Empty
        else {
            self.genre = []
        }
    }
}

nonisolated struct RemoteGenre: Decodable, Sendable {
    let value: String
    let albumCount: Int
    let songCount: Int
    
    enum CodingKeys: String, CodingKey {
        case value, name, albumCount, songCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. Decode Name
        if let v = try? container.decode(String.self, forKey: .value) {
            self.value = v
        } else if let n = try? container.decode(String.self, forKey: .name) {
            self.value = n
        } else {
            self.value = "Unknown"
        }
        
        // 2. Decode Counts (Inline Helper to avoid Isolation Warnings)
        func decodeInt(_ key: CodingKeys) -> Int {
            if let i = try? container.decode(Int.self, forKey: key) { return i }
            if let s = try? container.decode(String.self, forKey: key), let i = Int(s) { return i }
            return 0
        }
        
        self.albumCount = decodeInt(.albumCount)
        self.songCount = decodeInt(.songCount)
    }
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
    let genre: String?
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
    
    let artist: String?
    let album: String?
    let coverArt: String?
    let albumId: String?
}

// MARK: - 2. The Client Actor

actor NavidromeClient: NSObject {
    
    private let baseURL: URL
    private var session: URLSession!
    private let logger = Logger(subsystem: "com.loopapp", category: "NavidromeClient")
    
    private let username: String
    private let salt: String
    private let token: String
    
    init(baseURL: URL = URL(string: "http://192.168.0.40:4533")!,
         username: String = "boris",
         password: String = "Beaver-4600!",
         salt: String = String.randomSalt()) {
        
        self.baseURL = baseURL
        self.username = username
        self.salt = salt
        self.token = NavidromeClient.generateToken(password: password, salt: salt)
        
        super.init()
        
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, directory: nil)
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
        return buildURL(endpoint: "getCoverArt", params: ["id": id, "size": String(size)])
    }
    
    // MARK: - API Methods
    
    func search(query: String) async throws -> ([RemoteSong], [RemoteAlbum], [RemoteArtist]) {
        guard let url = buildURL(endpoint: "search3", params: ["query": query, "songCount": "20", "albumCount": "10", "artistCount": "10"]) else { throw URLError(.badURL) }
        let response: SubsonicSearchResponse = try await fetch(url: url)
        let result = response.subsonicResponse.searchResult3
        return (result?.song ?? [], result?.album ?? [], result?.artist ?? [])
    }
    
    func fetchArtist(id: String) async throws -> RemoteArtistDetail? {
        let response: SubsonicGetArtistResponse = try await fetch("getArtist", params: ["id": id])
        return response.subsonicResponse.artist
    }
    
    func fetchSong(id: String) async throws -> RemoteSong? {
        let response: SubsonicGetSongResponse = try await fetch("getSong", params: ["id": id])
        return response.subsonicResponse.song
    }
    
    // ✅ Updated getGenres with Raw JSON Debugging
    func getGenres() async throws -> [RemoteGenre] {
        guard let url = buildURL(endpoint: "getGenres", params: [:]) else { return [] }
        
        // 1. Fetch Raw Data first to debug
        let (data, _) = try await session.data(from: url)
        
        // Uncomment this line if it fails again to see the raw JSON in console:
        // if let jsonStr = String(data: data, encoding: .utf8) { print("📦 GENRES JSON: \(jsonStr)") }
        
        // 2. Decode
        do {
            let response = try JSONDecoder().decode(SubsonicGetGenresResponse.self, from: data)
            let list = response.subsonicResponse.genres?.genre ?? []
            logger.info("✅ Fetched \(list.count) genres")
            return list
        } catch {
            logger.error("❌ Genre Decode Error: \(error)")
            // Fallback for single object edge cases if DTO failed
            return []
        }
    }
    
    // Standard fetch
    func fetch<T: Decodable & Sendable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else { throw URLError(.badURL) }
        return try await fetch(url: url)
    }
    
    func fetch<T: Decodable & Sendable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else { throw URLError(.badServerResponse) }
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
        for (key, value) in params { queryItems.append(URLQueryItem(name: key, value: value)) }
        components?.queryItems = queryItems
        return components?.url
    }
    
    private static func generateToken(password: String, salt: String) -> String {
        let input = password + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - URLSessionDelegate
extension NavidromeClient: URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
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

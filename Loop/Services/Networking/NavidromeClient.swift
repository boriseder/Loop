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

nonisolated(unsafe) struct SubsonicResponse: Decodable, Sendable {
    let subsonicResponse: ResponseBody
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

nonisolated(unsafe) struct ResponseBody: Decodable, Sendable {
    let albumList2: AlbumList?
}

nonisolated(unsafe) struct AlbumList: Decodable, Sendable {
    let album: [RemoteAlbum]?
}

nonisolated(unsafe) struct RemoteAlbum: Decodable, Sendable {
    let id: String
    let name: String
    let artist: String
    let artistId: String
    let coverArt: String?
    let year: Int?
}

// MARK: - Album Details DTOs
nonisolated(unsafe)  struct SubsonicGetAlbumResponse: Decodable, Sendable {
    let subsonicResponse: GetAlbumBody
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

nonisolated(unsafe)  struct GetAlbumBody: Decodable, Sendable {
    let album: RemoteAlbumDetails?
}

nonisolated(unsafe)  struct RemoteAlbumDetails: Decodable, Sendable {
    let id: String
    let song: [RemoteSong]?
}

nonisolated(unsafe)  struct RemoteSong: Decodable, Sendable {
    let id: String
    let title: String
    let track: Int?
    let duration: Int?
    let path: String?
}

// MARK: - 2. The Client Actor

// ✅ FIX: Inherit from NSObject to be a URLSessionDelegate
//
//  NavidromeClient.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import OSLog
import CryptoKit

// ... [Keep all your DTO structs at the top: SubsonicResponse, etc.] ...
// ... [Keep structs: SubsonicGetAlbumResponse, etc.] ...

// ✅ FIX: Inherit from NSObject to be a URLSessionDelegate
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
    
    // ✅ NEW: Cover Art URL Generator
    nonisolated func coverArtURL(id: String, size: Int = 300) -> URL? {
        return buildURL(endpoint: "getCoverArt", params: [
            "id": id,
            "size": String(size)
        ])
    }
    
    func fetch<T: Decodable & Sendable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw URLError(.badURL)
        }
        
        logger.debug("Fetching: \(endpoint)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            logger.error("HTTP Error: \(response)")
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Image Fetching
        
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

// MARK: - URLSessionDelegate (Self-Signed Cert Logic)
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
    static func randomSalt(length: Int = 6) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

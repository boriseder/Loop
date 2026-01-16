//
//  NavidromeClient.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import OSLog

final class NavidromeClient: Sendable {
    
    private let logger = Logger(subsystem: "com.loopapp", category: "Network")
    private let storage = CredentialStorage.shared
    
    private var baseURL: String { storage.baseURL ?? "" }
    private var username: String { storage.username ?? "" }
    private var password: String { storage.password ?? "" }
    
    private var tokenParams: [String: String] {
        let salt = String((0..<6).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        let token = "\(password)\(salt)".md5
        return [
            "u": username,
            "t": token,
            "s": salt,
            "v": "1.16.1",
            "c": "iOSClient",
            "f": "json"
        ]
    }
    
    // MARK: - Generic Fetch
    func fetch<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard !baseURL.isEmpty else { throw URLError(.badURL) }
        
        var queryItems = tokenParams
        params.forEach { queryItems[$0.key] = $0.value }
        
        var urlComponents = URLComponents(string: "\(baseURL)/rest/\(endpoint)")
        urlComponents?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents?.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Asset URLs
    func coverArtURL(id: String, size: Int = 300) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        var query = tokenParams
        query["id"] = id
        query["size"] = String(size)
        
        var comps = URLComponents(string: "\(baseURL)/rest/getCoverArt")
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comps?.url
    }
    
    func streamURL(for songId: String) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        var query = tokenParams
        query["id"] = songId
        
        var comps = URLComponents(string: "\(baseURL)/rest/stream")
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comps?.url
    }
    
    func downloadData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    // MARK: - Specific Methods
    
    func fetchArtist(id: String) async throws -> RemoteArtist {
        let resp: SubsonicGetArtistResponse = try await fetch("getArtist", params: ["id": id])
        guard let artist = resp.subsonicResponse.artist else { throw URLError(.cannotParseResponse) }
        return artist
    }
    
    func getGenres() async throws -> [RemoteGenre] {
        let resp: SubsonicGenresResponse = try await fetch("getGenres")
        return resp.subsonicResponse.genres?.genre ?? []
    }
    
    func fetchSong(id: String) async throws -> RemoteSong? {
        let resp: SubsonicGetSongResponse = try await fetch("getSong", params: ["id": id])
        return resp.subsonicResponse.song
    }
    
    // ✅ ADDED: Search Method
    func search(query: String) async throws -> RemoteSearchResult {
        let params = [
            "query": query,
            "songCount": "20",
            "albumCount": "10",
            "artistCount": "5"
        ]
        
        let response: SubsonicSearchResponse = try await fetch("search3", params: params)
        guard let result = response.subsonicResponse.searchResult3 else {
            throw URLError(.cannotParseResponse)
        }
        return result
    }
}

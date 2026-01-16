//
//  NavidromeClient.swift
//  Loop
//
//  FIXED: Explicit nonisolated decode to prevent Swift 6 warnings
//

import Foundation
import OSLog
import CryptoKit

actor NavidromeClient {
    
    private let logger = Logger(subsystem: "com.loopapp", category: "Network")
    private let session: URLSession
    
    private var currentSession: Credentials?
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Auth Management
    
    func setSession(_ credentials: Credentials) {
        self.currentSession = credentials
    }
    
    func clearSession() {
        self.currentSession = nil
    }
    
    // MARK: - Generic Fetch
    
    func fetch<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard let credentials = currentSession else {
            throw NetworkError.notAuthenticated
        }
        
        var queryItems = buildTokenParams(for: credentials)
        params.forEach { queryItems[$0.key] = $0.value }
        
        var urlComponents = URLComponents(string: "\(credentials.baseURL)/rest/\(endpoint)")
        urlComponents?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        return try await Self.performFetch(url: url, session: session, logger: logger)
    }
    
    // ✅ FIXED: Static nonisolated fetch method for decoding
    private static nonisolated func performFetch<T: Decodable>(url: URL, session: URLSession, logger: Logger, attempt: Int = 1) async throws -> T {
        let maxRetries = 3
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                // ✅ Decode in nonisolated context
                return try JSONDecoder().decode(T.self, from: data)
                
            case 401, 403:
                throw NetworkError.authenticationFailed
                
            case 500...599:
                throw NetworkError.serverError(code: httpResponse.statusCode)
                
            default:
                throw NetworkError.httpError(code: httpResponse.statusCode)
            }
            
        } catch {
            if attempt < maxRetries, Self.shouldRetry(error) {
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                logger.warning("Request failed, retrying (\(attempt)/\(maxRetries)): \(error.localizedDescription)")
                try await Task.sleep(nanoseconds: delay)
                return try await performFetch(url: url, session: session, logger: logger, attempt: attempt + 1)
            }
            throw Self.mapError(error)
        }
    }
    
    private static func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .timedOut,
                .networkConnectionLost,
                .notConnectedToInternet
            ].contains(urlError.code)
        }
        return false
    }
    
    private static func mapError(_ error: Error) -> NetworkError {
        if let netError = error as? NetworkError { return netError }
        return .networkFailure(underlying: error)
    }
    
    // MARK: - Asset URLs
    
    func coverArtURL(id: String, size: Int = 300) async -> URL? {
        guard let credentials = currentSession else { return nil }
        var query = buildTokenParams(for: credentials)
        query["id"] = id
        query["size"] = String(size)
        
        var comps = URLComponents(string: "\(credentials.baseURL)/rest/getCoverArt")
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comps?.url
    }
    
    func streamURL(for songId: String) async -> URL? {
        guard let credentials = currentSession else { return nil }
        var query = buildTokenParams(for: credentials)
        query["id"] = songId
        
        var comps = URLComponents(string: "\(credentials.baseURL)/rest/stream")
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comps?.url
    }
    
    func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.downloadFailed
        }
        
        return data
    }
    
    // MARK: - Helpers
    
    /// Generates Subsonic token parameters safely
    private func buildTokenParams(for credentials: Credentials) -> [String: String] {
        let salt = String((0..<6).map { _ in
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!
        })
        
        let input = "\(credentials.password)\(salt)"
        let digest = Insecure.MD5.hash(data: input.data(using: .utf8) ?? Data())
        let token = digest.map { String(format: "%02hhx", $0) }.joined()
        
        return [
            "u": credentials.username,
            "t": token,
            "s": salt,
            "v": "1.16.1",
            "c": "iOSClient",
            "f": "json"
        ]
    }
}

enum NetworkError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case notFound
    case serverError(code: Int)
    case httpError(code: Int)
    case networkFailure(underlying: Error)
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please log in."
        case .invalidURL: return "Invalid server URL"
        case .invalidResponse: return "Invalid response from server"
        case .authenticationFailed: return "Authentication failed. Check your credentials."
        case .notFound: return "Resource not found"
        case .serverError(let code): return "Server error (code: \(code))"
        case .httpError(let code): return "Request failed (code: \(code))"
        case .networkFailure(let error): return "Network error: \(error.localizedDescription)"
        case .downloadFailed: return "Download failed"
        }
    }
}

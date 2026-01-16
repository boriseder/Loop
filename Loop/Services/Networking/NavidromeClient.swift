//
//  NavidromeClient.swift
//  Loop
//
//  Thread-safe networking with proper error handling
//

import Foundation
import OSLog

actor NavidromeClient {
    
    private let logger = Logger(subsystem: "com.loopapp", category: "Network")
    private let session: URLSession
    private let maxRetries = 3
    
    private var cachedCredentials: Credentials?
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Credential Management
    
    func updateCredentials(_ credentials: Credentials) {
        self.cachedCredentials = credentials
    }
    
    private func getCredentials() async throws -> Credentials {
        if let cached = cachedCredentials {
            return cached
        }
        
        guard let stored = await KeychainStorage.shared.credentials else {
            throw NetworkError.notAuthenticated
        }
        
        cachedCredentials = stored
        return stored
    }
    
    // MARK: - Generic Fetch
    
    func fetch<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        let credentials = try await getCredentials()
        
        var queryItems = credentials.tokenParams
        params.forEach { queryItems[$0.key] = $0.value }
        
        var urlComponents = URLComponents(string: "\(credentials.baseURL)/rest/\(endpoint)")
        urlComponents?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        return try await fetchWithRetry(url: url)
    }
    
    private func fetchWithRetry<T: Decodable>(url: URL, attempt: Int = 1) async throws -> T {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded
                
            case 401:
                // Clear cached credentials on auth failure
                cachedCredentials = nil
                throw NetworkError.authenticationFailed
                
            case 404:
                throw NetworkError.notFound
                
            case 500...599:
                throw NetworkError.serverError(code: httpResponse.statusCode)
                
            default:
                throw NetworkError.httpError(code: httpResponse.statusCode)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            // Retry on network errors
            if attempt < maxRetries {
                logger.warning("Request failed, retrying (\(attempt)/\(self.maxRetries)): \(error.localizedDescription)")
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000) // Exponential backoff
                return try await fetchWithRetry(url: url, attempt: attempt + 1)
            }
            throw NetworkError.networkFailure(underlying: error)
        }
    }
    
    // MARK: - Asset URLs
    
    func coverArtURL(id: String, size: Int = 300) async throws -> URL {
        let credentials = try await getCredentials()
        var query = credentials.tokenParams
        query["id"] = id
        query["size"] = String(size)
        
        var comps = URLComponents(string: "\(credentials.baseURL)/rest/getCoverArt")
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = comps?.url else {
            throw NetworkError.invalidURL
        }
        return url
    }
    
    func streamURL(for songId: String) async throws -> URL {
        let credentials = try await getCredentials()
        var query = credentials.tokenParams
        query["id"] = songId
        
        var comps = URLComponents(string: "\(credentials.baseURL)/rest/stream")
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = comps?.url else {
            throw NetworkError.invalidURL
        }
        return url
    }
    
    func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.downloadFailed
        }
        
        return data
    }
}

// MARK: - Error Types

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
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed. Check your credentials."
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .httpError(let code):
            return "Request failed (code: \(code))"
        case .networkFailure(let error):
            return "Network error: \(error.localizedDescription)"
        case .downloadFailed:
            return "Download failed"
        }
    }
}

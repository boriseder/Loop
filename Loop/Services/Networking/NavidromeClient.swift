import Foundation
import OSLog
import CryptoKit

actor NavidromeClient {
    private let session: URLSession
    private let logger = Logger(subsystem: "com.loopapp", category: "Network")
    private var currentSession: Credentials?
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func setSession(_ credentials: Credentials) {
        self.currentSession = credentials
    }
    
    func clearSession() {
        self.currentSession = nil
    }
    
    func fetch<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard let credentials = currentSession else { throw NetworkError.notAuthenticated }
        
        let url = try constructURL(endpoint: endpoint, params: params, credentials: credentials)
        return try await performRequest(url: url)
    }
    
    func coverArtURL(id: String, size: Int) -> URL? {
        guard let credentials = currentSession else { return nil }
        let params = ["id": id, "size": String(size)]
        return try? constructURL(endpoint: "getCoverArt", params: params, credentials: credentials)
    }
    
    func streamURL(for songId: String) -> URL? {
        guard let credentials = currentSession else { return nil }
        return try? constructURL(endpoint: "stream", params: ["id": songId], credentials: credentials)
    }
    
    func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetworkError.downloadFailed
        }
        return data
    }
    
    // MARK: - Private Helpers
    
    private func constructURL(endpoint: String, params: [String: String], credentials: Credentials) throws -> URL {
        var queryItems = buildTokenParams(for: credentials)
        params.forEach { queryItems[$0.key] = $0.value }
        
        var components = URLComponents(string: "\(credentials.baseURL)/rest/\(endpoint)")
        components?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components?.url else { throw NetworkError.invalidURL }
        return url
    }
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        
        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                logger.error("Decoding error for \(url.absoluteString): \(error)")
                throw NetworkError.decodingError(error)
            }
        case 401, 403: throw NetworkError.authenticationFailed
        case 500...599: throw NetworkError.serverError(code: http.statusCode)
        default: throw NetworkError.httpError(code: http.statusCode)
        }
    }
    
    private func buildTokenParams(for credentials: Credentials) -> [String: String] {
        let salt = String((0..<6).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
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
    case notAuthenticated, invalidURL, invalidResponse, authenticationFailed, downloadFailed
    case serverError(code: Int)
    case httpError(code: Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated"
        case .invalidURL: return "Invalid URL"
        case .downloadFailed: return "Download failed"
        case .serverError(let c): return "Server error \(c)"
        case .authenticationFailed: return "Auth failed"
        default: return "Network error"
        }
    }
}

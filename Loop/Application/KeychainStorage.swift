//
//  KeychainStorage.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  KeychainStorage.swift
//  Loop
//
//  Secure credential storage using Keychain
//

import Foundation
import Security

actor KeychainStorage {
    static let shared = KeychainStorage()
    
    private let service = "at.amtabor.loop"
    
    private enum Key: String {
        case baseURL = "baseURL"
        case username = "username"
        case password = "password"
    }
    
    // MARK: - Public Interface
    
    var credentials: Credentials? {
        get async {
            guard let url = await getString(.baseURL),
                  let user = await getString(.username),
                  let pass = await getString(.password) else {
                return nil
            }
            return Credentials(baseURL: url, username: user, password: pass)
        }
    }
    
    func save(credentials: Credentials) async throws {
        try await setString(credentials.baseURL, for: .baseURL)
        try await setString(credentials.username, for: .username)
        try await setString(credentials.password, for: .password)
    }
    
    func clear() async {
        await deleteString(.baseURL)
        await deleteString(.username)
        await deleteString(.password)
    }
    
    // MARK: - Private Helpers
    
    private func getString(_ key: Key) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func setString(_ value: String, for key: Key) async throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // Try to update first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, add it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(status: updateStatus)
        }
    }
    
    private func deleteString(_ key: Key) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Supporting Types

struct Credentials: Sendable {
    let baseURL: String
    let username: String
    let password: String
    
    var tokenParams: [String: String] {
        let salt = String((0..<6).map { _ in 
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! 
        })
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
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode credential data"
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        }
    }
}
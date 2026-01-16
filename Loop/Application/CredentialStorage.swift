//
//  CredentialStorage.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  CredentialStorage.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation

final class CredentialStorage {
    static let shared = CredentialStorage()
    
    private let defaults = UserDefaults.standard
    
    private let keyURL = "loop.auth.url"
    private let keyUser = "loop.auth.user"
    private let keyPass = "loop.auth.pass" // In production, use Keychain
    
    var baseURL: String? {
        get { defaults.string(forKey: keyURL) }
        set { defaults.set(newValue, forKey: keyURL) }
    }
    
    var username: String? {
        get { defaults.string(forKey: keyUser) }
        set { defaults.set(newValue, forKey: keyUser) }
    }
    
    var password: String? {
        get { defaults.string(forKey: keyPass) }
        set { defaults.set(newValue, forKey: keyPass) }
    }
    
    var hasCredentials: Bool {
        return baseURL != nil && username != nil && password != nil
    }
    
    func clear() {
        defaults.removeObject(forKey: keyURL)
        defaults.removeObject(forKey: keyUser)
        defaults.removeObject(forKey: keyPass)
    }
}
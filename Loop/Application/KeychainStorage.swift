import Foundation
import Security

actor KeychainStorage {
    static let shared = KeychainStorage()
    private let service = "at.amtabor.loop"
    
    func save(credentials: Credentials) throws {
        try saveItem(credentials.baseURL, for: "baseURL")
        try saveItem(credentials.username, for: "username")
        try saveItem(credentials.password, for: "password")
    }
    
    var credentials: Credentials? {
        get {
            guard let url = getItem("baseURL"),
                  let user = getItem("username"),
                  let pass = getItem("password") else { return nil }
            return Credentials(baseURL: url, username: user, password: pass)
        }
    }
    
    func clear() {
        deleteItem("baseURL")
        deleteItem("username")
        deleteItem("password")
    }
    
    private func saveItem(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getItem(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func deleteItem(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

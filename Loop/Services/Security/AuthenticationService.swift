//
//  AuthenticationService.swift
//  Loop
//
//  FIXED: Removed async race condition in init. Added explicit restoreSession().
//

import Foundation
import Observation

@Observable @MainActor
final class AuthenticationService {
    
    var isAuthenticated: Bool = false
    var authError: String?
    
    private let keychain = KeychainStorage.shared
    private let client: NavidromeClient
    private let syncManager: SyncManager
    
    init(client: NavidromeClient, syncManager: SyncManager) {
        self.client = client
        self.syncManager = syncManager
        // ❌ REMOVED: The fire-and-forget Task that caused the race condition
    }
    
    // ✅ NEW: Explicit method to restore session
    func restoreSession() async {
        if let credentials = await keychain.credentials {
            await client.setSession(credentials)
            self.isAuthenticated = true
        }
    }
    
    func login(credentials: Credentials) async {
        authError = nil
        do {
            // 1. Validate with Server
            await client.setSession(credentials)
            let _: SubsonicPingResponse = try await client.fetch("ping")
            
            // 2. Persist
            try await keychain.save(credentials: credentials)
            
            // 3. Update State
            self.isAuthenticated = true
            
            // 4. Trigger Sync
            try? await syncManager.performSmartSync()
            
        } catch {
            await client.clearSession()
            self.isAuthenticated = false
            self.authError = error.localizedDescription
        }
    }
    
    func logout() async {
        await keychain.clear()
        await client.clearSession()
        self.isAuthenticated = false
    }
}

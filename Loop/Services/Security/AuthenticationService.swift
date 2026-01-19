import Foundation
import Observation

@Observable @MainActor
final class AuthenticationService {
    var isAuthenticated = false
    var authError: String?
    
    private let client: NavidromeClient
    private let syncManager: SyncManager
    private let keychain = KeychainStorage.shared
    
    init(client: NavidromeClient, syncManager: SyncManager) {
        self.client = client
        self.syncManager = syncManager
        
        Task { await restoreSession() }
    }
    
    func restoreSession() async {
        if let creds = await keychain.credentials {
            await client.setSession(creds)
            self.isAuthenticated = true
            syncManager.startSmartSync()
        }
    }
    
    func login(credentials: Credentials) async {
        do {
            await client.setSession(credentials)
            let _: SubsonicPingResponse = try await client.fetch("ping")
            try await keychain.save(credentials: credentials)
            self.isAuthenticated = true
            syncManager.startSmartSync(force: true)
        } catch {
            authError = error.localizedDescription
            await client.clearSession()
        }
    }
    
    func logout() async {
        await keychain.clear()
        await client.clearSession()
        self.isAuthenticated = false
    }
}

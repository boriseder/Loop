import SwiftUI

struct SettingsView: View {
    let auth: AuthenticationService
    let cache: CoverArtCache
    
    var body: some View {
        List {
            Section("Account") {
                Button("Logout", role: .destructive) {
                    Task { await auth.logout() }
                }
            }
            
            Section("Storage") {
                Button("Clear Image Cache") {
                    Task { await cache.clearCache() }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

import Foundation
import SwiftData

@MainActor
final class MusicDatabase {
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            Album.self,
            Artist.self,
            Genre.self,
            Song.self
        ])
        
        // Disable iCloud syncing for local cache DB to improve performance/reliability
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize MusicDatabase: \(error)")
        }
    }
}

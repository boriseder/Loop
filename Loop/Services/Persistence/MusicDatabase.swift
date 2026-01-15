//
//  MusicDatabase.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftData
import Foundation

@Observable
final class MusicDatabase {
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            Loop.Song.self,
            Loop.Album.self,
            Loop.Artist.self,
            Loop.Genre.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // ✅ Disable autosave to ensure we control transactions
            container.mainContext.autosaveEnabled = false
            print("✅ MusicDatabase: Container ready")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

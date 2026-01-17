//
//  MusicDatabase.swift
//  Loop
//
//  FIXED: Ensured all models (Album, Artist, Genre, Song) are in the Schema
//

import Foundation
import SwiftData

@MainActor
final class MusicDatabase {
    let container: ModelContainer
    
    init() {
        // ✅ CRITICAL: Ensure Loop.Artist is included here!
        let schema = Schema([
            Loop.Album.self,
            Loop.Artist.self,
            Loop.Genre.self,
            Loop.Song.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ MusicDatabase: Container ready")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

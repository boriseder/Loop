//
//  MusicDatabase.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftData
import SwiftUI
import Foundation // Needed for FileManager

@MainActor
final class MusicDatabase {
    let container: ModelContainer
    
    init() {
        let schema = Schema([Song.self, Album.self, Artist.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        // ✅ FIX: Ensure the directory exists to prevent CoreData 512 errors
        let fileManager = FileManager.default
        if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: supportDir.path) {
                try? fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
            }
        }
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            print("✅ MusicDatabase: Container ready")
        } catch {
            fatalError("❌ MusicDatabase Init Failed: \(error)")
        }
    }
}

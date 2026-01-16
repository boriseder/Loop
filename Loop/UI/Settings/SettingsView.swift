//
//  SettingsView.swift
//  Loop
//
//  FIXED: Uses AuthEnvironment and MusicEnvironment
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthEnvironment.self) private var auth
    @Environment(MusicEnvironment.self) private var music
    @Environment(\.dismiss) private var dismiss
    
    @State private var cacheSize: String = "Calculating..."
    @State private var isClearing = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Status", value: auth.isAuthenticated ? "Logged In" : "Not Logged In")
                    
                    Button("Logout", role: .destructive) {
                        Task {
                            await auth.logout()
                            dismiss()
                        }
                    }
                }
                
                Section("Storage") {
                    LabeledContent("Image Cache", value: cacheSize)
                    
                    Button("Clear Image Cache") {
                        isClearing = true
                        Task {
                            await clearImageCache()
                            await calculateCacheSize()
                            isClearing = false
                        }
                    }
                    .disabled(isClearing || cacheSize == "0 KB")
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await calculateCacheSize()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func calculateCacheSize() async {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docDir = urls.first else { return }
        let coversDir = docDir.appendingPathComponent("Covers")
        
        var totalSize: Int64 = 0
        
        if let files = try? fileManager.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in files {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        self.cacheSize = formattedSize
    }
    
    private func clearImageCache() async {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docDir = urls.first else { return }
        let coversDir = docDir.appendingPathComponent("Covers")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
}

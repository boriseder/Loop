//
//  SettingsView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var cacheSize: String = "Calculating..."
    @State private var isClearing = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Server", value: CredentialStorage.shared.baseURL ?? "Unknown")
                    LabeledContent("User", value: CredentialStorage.shared.username ?? "Unknown")
                    
                    Button("Logout", role: .destructive) {
                        container.logout()
                        dismiss()
                    }
                }
                
                Section("Storage") {
                    LabeledContent("Image Cache", value: cacheSize)
                    
                    Button("Clear Image Cache") {
                        isClearing = true
                        Task {
                            await clearImageCache()
                            calculateCacheSize()
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
            .onAppear {
                calculateCacheSize()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func calculateCacheSize() {
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            guard let docDir = urls.first else { return }
            let coversDir = docDir.appendingPathComponent("Covers")
            
            var totalSize: Int64 = 0
            
            // ✅ FIX: Use contentsOfDirectory for safe Swift 6 concurrency
            if let files = try? fileManager.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for fileURL in files {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let size = resourceValues.fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
            
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            
            await MainActor.run {
                self.cacheSize = formattedSize
            }
        }
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

//
//  SyncProgressView.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  SyncProgressView.swift
//  Loop
//
//  Modal overlay showing sync progress
//

import SwiftUI

struct SyncProgressView: View {
    let progress: SyncProgress
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Progress card
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    if case .complete = progress.phase {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else if case .failed = progress.phase {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.primary)
                    }
                }
                .animation(.spring(response: 0.5), value: progress.phase)
                
                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)
                            
                            // Foreground
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * progress.progressPercent, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: progress.progressPercent)
                        }
                    }
                    .frame(height: 8)
                    
                    // Percentage
                    Text("\(Int(progress.progressPercent * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: 280)
                
                // Status text
                VStack(spacing: 4) {
                    Text(progress.displayText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    if case .failed = progress.phase {
                        Text("Check your connection and try again")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Cancel button (only during sync)
                if progress.isActive {
                    Button("Cancel", role: .destructive) {
                        onCancel()
                    }
                    .font(.subheadline)
                    .padding(.top, 8)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(40)
        }
    }
}

#Preview {
    SyncProgressView(
        progress: SyncProgress(phase: .albums(current: 234, total: 491)),
        onCancel: {}
    )
}

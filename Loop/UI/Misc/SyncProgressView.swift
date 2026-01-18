//
//  SyncProgressView.swift
//  Loop
//
//  Fixed: Consistent size regardless of text length
//

import SwiftUI

struct SyncProgressView: View {
    let progress: SyncProgress
    let onCancel: () -> Void
    
    @State private var rotate = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Progress card with FIXED dimensions
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.8))
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
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.8))
                            .rotationEffect(.degrees(rotate ? 360 : 0))
                            .animation(
                                .linear(duration: 4).repeatForever(autoreverses: false),
                                value: rotate
                            )
                            .onAppear {
                                rotate = true
                            }
                    }
                }
                //
                .animation(.spring(response: 0.5), value: progress.phase)
                
                // Progress bar
                VStack(spacing: 4) {
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
                .frame(width: 280) // ✅ Fixed width
                
                // Status text with FIXED HEIGHT
                VStack(spacing: 4) {
                    Text(progress.displayText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 16, alignment: .center) // ✅ Fixed height for 2 lines
                    
                    // Error message (fixed space)
                    Group {
                        if case .failed = progress.phase {
                            Text("Check your connection and try again")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ") // Invisible placeholder to maintain spacing
                                .font(.caption)
                        }
                    }
                    .frame(height: 24) // ✅ Fixed height for error message
                }
                .frame(width: 280) // ✅ Fixed width
                
                // Cancel button (fixed space)
                Group {
                    if progress.isActive {
                        Button("Cancel", role: .destructive) {
                            onCancel()
                        }
                        .font(.subheadline)
                    } else {
                        // Invisible placeholder
                        Text(" ")
                            .font(.subheadline)
                    }
                }
                .frame(height: 16) // ✅ Fixed height for button area
            }
            .padding(16)
            .frame(width: 312) // ✅ Total fixed width (280 + 16*2)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 16)
        }
    }
}

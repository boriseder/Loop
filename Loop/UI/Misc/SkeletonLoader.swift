//
//  SkeletonLoader.swift
//  Loop
//
//  FIXED: Added explicit sizing for LazyVGrid
//

import SwiftUI

// MARK: - Grid Skeleton (Library)
struct AlbumGridSkeleton: View {
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<12, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    // Cover Placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 160, height: 160) // ✅ FIXED: Explicit size
                    
                    // Title Line
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 16)
                        .frame(width: 120)
                    
                    // Artist Line
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 12)
                        .frame(width: 80)
                }
                .shimmering()
            }
        }
    }
}

// MARK: - Detail Skeleton (Album/Artist)
struct AlbumDetailSkeleton: View {
    var body: some View {
        VStack(spacing: 24) {
            // Header Section
            HStack(alignment: .bottom, spacing: 20) {
                // Cover
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                // Info
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 24)
                        .frame(maxWidth: 200)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 16)
                        .frame(width: 120)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 12)
                        .frame(width: 80)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider().padding(.horizontal)
            
            // Songs List
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    HStack(spacing: 16) {
                        // Track Num
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 20, height: 16)
                        
                        // Title
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                        
                        // Duration
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 40, height: 16)
                    }
                    .padding()
                    
                    Divider().padding(.leading, 16)
                }
            }
        }
        .shimmering()
    }
}

// MARK: - Shimmer Effect
extension View {
    func shimmering() -> some View {
        modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    .white.opacity(0.2),
                                    .clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: -geo.size.width + (phase * (geo.size.width * 3)))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

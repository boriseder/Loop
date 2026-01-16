//
//  ShimmerEffect.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  SkeletonLoader.swift
//  Loop
//
//  Reusable skeleton loading views
//

import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
            .mask(content)
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Album Grid Skeleton

struct AlbumGridSkeleton: View {
    let count: Int = 6
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<count, id: \.self) { _ in
                AlbumCellSkeleton()
            }
        }
        .padding()
    }
}

struct AlbumCellSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 180, height: 180)
                .shimmer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 16)
                .shimmer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 100, height: 12)
                .shimmer()
        }
    }
}

// MARK: - List Row Skeleton

struct ListRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 60, height: 60)
                .shimmer()
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 16)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 12)
                    .shimmer()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ListSkeletonView: View {
    let count: Int = 8
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                ListRowSkeleton()
                Divider()
            }
        }
    }
}

// MARK: - Album Detail Skeleton

struct AlbumDetailSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .shimmer()
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 180, height: 20)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 120, height: 16)
                            .shimmer()
                    }
                    
                    HStack(spacing: 20) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 120, height: 44)
                            .shimmer()
                        
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .shimmer()
                    }
                }
                .padding(.top, 20)
                
                Divider().padding(.horizontal)
                
                // Track list
                LazyVStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { _ in
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 25, height: 16)
                                .shimmer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 16)
                                    .shimmer()
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 100, height: 12)
                                    .shimmer()
                            }
                            
                            Spacer()
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 40, height: 12)
                                .shimmer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.leading, 50)
                    }
                }
            }
        }
    }
}

#Preview("Album Grid") {
    AlbumGridSkeleton()
}

#Preview("List") {
    ListSkeletonView()
}

#Preview("Album Detail") {
    AlbumDetailSkeleton()
}
//
//  ScaleButtonStyle.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  ViewTransitions.swift
//  Loop
//
//  Custom view transitions and animations
//

import SwiftUI

// MARK: - Custom Transitions

extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.95).combined(with: .opacity)
    }
    
    static var slideUp: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Smooth Appear Modifier

struct SmoothAppear: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func smoothAppear(delay: Double = 0) -> some View {
        modifier(SmoothAppear(delay: delay))
    }
}

// MARK: - Staggered Grid Animation

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.05)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
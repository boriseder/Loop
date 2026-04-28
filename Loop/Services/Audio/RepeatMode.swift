//
//  isolation.swift
//  Loop
//
//  Created by EDER Boris (ICS480-ECC) on 28.04.26.
//


// RepeatMode.swift
// Declared in its own file so Swift 6 cannot infer actor isolation from neighbours.

import Foundation

enum RepeatMode: CaseIterable, Equatable, Sendable {
    case off    // Stop after queue ends
    case all    // Loop entire queue
    case one    // Repeat current song indefinitely

    var systemImageName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var isActive: Bool { self != .off }
}
//
//  SyncProgress.swift
//  Loop
//
//  Models for tracking sync progress across the app
//

import Foundation

struct SyncProgress: Sendable {
    enum Phase: Sendable, Equatable {
        case idle
        case albums(current: Int, total: Int)
        case genres
        case covers(current: Int, total: Int)
        case complete
        case failed(error: String)
    }
    
    let phase: Phase
    
    var isActive: Bool {
        switch phase {
        case .idle, .complete, .failed:
            return false
        default:
            return true
        }
    }
    
    var progressPercent: Double {
        switch phase {
        case .albums(let current, let total):
            guard total > 0 else { return 0 }
            return Double(current) / Double(total) * 0.6 // Albums = 60% of total
        case .genres:
            return 0.65
        case .covers(let current, let total):
            guard total > 0 else { return 0.65 }
            return 0.65 + (Double(current) / Double(total) * 0.35) // Covers = 35% of total
        case .complete:
            return 1.0
        default:
            return 0
        }
    }
    
    var displayText: String {
        switch phase {
        case .idle:
            return "Ready"
        case .albums(let current, let total):
            return "Syncing albums \(current)/\(total)..."
        case .genres:
            return "Syncing genres..."
        case .covers(let current, let total):
            return "Downloading covers \(current)/\(total)..."
        case .complete:
            return "Sync complete"
        case .failed(let error):
            return "Sync failed: \(error)"
        }
    }
}

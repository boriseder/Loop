//
//  PlaybackPersistence.swift
//  Loop
//
//  FIXED: Added shuffle and repeat modes
//  NOTE: This file REPLACES the old Loop/Services/Persistence/PlaybackPersistence.swift
//

import Foundation

// 1. The Data Model
struct PlaybackState: Codable {
    let currentSongId: String
    let queue: [String]
    let elapsed: Double
    let isShuffled: Bool
    let repeatMode: RepeatMode
    
    init(currentSongId: String, queue: [String], elapsed: Double, isShuffled: Bool = false, repeatMode: RepeatMode = .off) {
        self.currentSongId = currentSongId
        self.queue = queue
        self.elapsed = elapsed
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
    }
}

enum RepeatMode: String, Codable {
    case off
    case all
    case one
    
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
    
    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

// 2. The Protocol (Interface)
protocol PlaybackPersistence {
    func save(_ state: PlaybackState)
    func load() -> PlaybackState?
}

// 3. The Concrete Implementation
struct UserDefaultsPersistence: PlaybackPersistence {
    private let key = "loop.playback.state"
    
    func save(_ state: PlaybackState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func load() -> PlaybackState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlaybackState.self, from: data)
    }
}

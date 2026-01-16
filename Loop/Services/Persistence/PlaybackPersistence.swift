//
//  PlaybackPersistence.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation

// 1. The Data Model
struct PlaybackState: Codable {
    let currentSongId: String
    let queue: [String]
    let elapsed: Double
}

// 2. The Protocol (Interface)
protocol PlaybackPersistence {
    func save(_ state: PlaybackState)
    func load() -> PlaybackState?
}

// 3. The Concrete Implementation (The actual logic)
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

//
//  PlaybackPersistence.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation

// ✅ The DTO that AudioEngine was missing
struct PlaybackState: Codable {
    let currentSongId: String
    let queue: [String]
    let elapsed: Double
}

protocol PlaybackPersistence {
    func save(_ state: PlaybackState)
    func load() -> PlaybackState?
}

// ✅ Concrete Implementation
final class UserDefaultsPlaybackPersistence: PlaybackPersistence {
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

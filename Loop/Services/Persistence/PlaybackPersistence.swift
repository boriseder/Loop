import Foundation

// Simple struct - no Codable isolation issues
struct PlaybackState: Sendable {
    let currentSongId: String
    let queue: [String]
    let progress: Double
}

actor PlaybackPersistence {
    private let userDefaults = UserDefaults.standard
    private let key = "playbackState"
    
    func save(_ state: PlaybackState) {
        // Manual encoding to avoid Codable isolation issues
        let dict: [String: Any] = [
            "currentSongId": state.currentSongId,
            "queue": state.queue,
            "progress": state.progress
        ]
        userDefaults.set(dict, forKey: key)
    }
    
    func load() -> PlaybackState? {
        guard let dict = userDefaults.dictionary(forKey: key),
              let currentSongId = dict["currentSongId"] as? String,
              let queue = dict["queue"] as? [String],
              let progress = dict["progress"] as? Double else {
            return nil
        }
        
        return PlaybackState(
            currentSongId: currentSongId,
            queue: queue,
            progress: progress
        )
    }
    
    func clear() {
        userDefaults.removeObject(forKey: key)
    }
}

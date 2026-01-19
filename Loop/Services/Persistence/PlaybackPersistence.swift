import Foundation

struct PlaybackState: Codable, Sendable {
    let currentSongId: String
    let queue: [String]
    let progress: Double
}

actor PlaybackPersistence {
    func save(_ state: PlaybackState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "playbackState")
        }
    }
    
    func load() -> PlaybackState? {
        guard let data = UserDefaults.standard.data(forKey: "playbackState") else { return nil }
        return try? JSONDecoder().decode(PlaybackState.self, from: data)
    }
}

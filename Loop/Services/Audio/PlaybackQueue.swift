// PlaybackQueue.swift
import Foundation

// MARK: - PlaybackQueue Actor
/// Thread-safe, single source of truth for queue, shuffle, and repeat state.
/// All public methods are safe to call from any isolation domain.
actor PlaybackQueue {

    // MARK: - State
    private var originalQueue: [String] = []
    private var shuffledQueue: [String] = []
    private var currentIndex: Int = 0

    private(set) var isShuffled: Bool = false
    private(set) var repeatMode: RepeatMode = .off

    // MARK: - Derived helpers

    private var activeQueue: [String] {
        isShuffled ? shuffledQueue : originalQueue
    }

    var currentSongId: String? {
        let q = activeQueue
        guard currentIndex >= 0, currentIndex < q.count else { return nil }
        return q[currentIndex]
    }

    var nextSongId: String? {
        switch repeatMode {
        case .one:
            return currentSongId
        case .all:
            let q = activeQueue
            guard !q.isEmpty else { return nil }
            return q[(currentIndex + 1) % q.count]
        case .off:
            let q = activeQueue
            let next = currentIndex + 1
            return next < q.count ? q[next] : nil
        }
    }

    var previousSongId: String? {
        let q = activeQueue
        guard currentIndex > 0 else {
            return repeatMode == .all ? q.last : nil
        }
        return q[currentIndex - 1]
    }

    // MARK: - Mutations

    func setQueue(_ ids: [String], startingAt songId: String) {
        originalQueue = ids
        currentIndex = ids.firstIndex(of: songId) ?? 0
        if isShuffled {
            rebuildShuffledQueue(keepingCurrent: songId)
        }
    }

    @discardableResult
    func advance() -> String? {
        let q = activeQueue
        guard !q.isEmpty else { return nil }

        switch repeatMode {
        case .one:
            break
        case .all:
            currentIndex = (currentIndex + 1) % q.count
        case .off:
            if currentIndex < q.count - 1 {
                currentIndex += 1
            } else {
                return nil
            }
        }
        return currentSongId
    }

    @discardableResult
    func stepBack() -> String? {
        let q = activeQueue
        guard !q.isEmpty else { return nil }

        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all {
            currentIndex = q.count - 1
        }
        return currentSongId
    }

    @discardableResult
    func seek(to songId: String) -> String? {
        let q = activeQueue
        guard let idx = q.firstIndex(of: songId) else { return nil }
        currentIndex = idx
        return currentSongId
    }

    // MARK: - Shuffle

    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            rebuildShuffledQueue(keepingCurrent: currentSongId)
        } else {
            if let current = currentSongId,
               let idx = originalQueue.firstIndex(of: current) {
                currentIndex = idx
            }
        }
    }

    // MARK: - Repeat

    func cycleRepeatMode() {
        let all = RepeatMode.allCases
        let next = (all.firstIndex(of: repeatMode)! + 1) % all.count
        repeatMode = all[next]
    }

    // MARK: - Private

    private func rebuildShuffledQueue(keepingCurrent songId: String?) {
        var pool = originalQueue
        if let id = songId, let idx = pool.firstIndex(of: id) {
            pool.remove(at: idx)
        }
        pool.shuffle()
        shuffledQueue = songId.map { [$0] + pool } ?? pool
        currentIndex = 0
    }
}

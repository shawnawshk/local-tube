import Foundation
import Observation

/// Remembers where each video (keyed by path) was left off, and when it was last played.
@Observable
final class ProgressStore {
    struct Entry: Codable, Equatable {
        var position: Double
        var duration: Double
        /// Nil once removed from Recent, and for progress saved before Recent existed.
        var lastPlayed: Date?
    }

    /// Stopping within this many seconds of the end counts as watched.
    static let watchedMargin: Double = 10

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "progress"
    private(set) var entries: [String: Entry]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        entries = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
    }

    func entry(for url: URL) -> Entry? {
        entries[url.path]
    }

    func save(position: Double, duration: Double, for url: URL) {
        guard duration > 0, position.isFinite else { return }
        entries[url.path] = Entry(position: min(max(position, 0), duration), duration: duration, lastPlayed: Date())
        persist()
    }

    /// The most recently played videos, newest first. Files that were moved or deleted are left out.
    func recent(limit: Int) -> [URL] {
        let played = entries.compactMap { path, entry in entry.lastPlayed.map { (path, $0) } }
        return Array(played.sorted { $0.1 > $1.1 }.lazy
            .map { URL(fileURLWithPath: $0.0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(limit))
    }

    /// Takes the video off Recent; its progress stays.
    func removeFromRecent(_ url: URL) {
        entries[url.path]?.lastPlayed = nil
        persist()
    }

    /// Empties Recent; all progress stays.
    func clearRecent() {
        for path in entries.keys { entries[path]?.lastPlayed = nil }
        persist()
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: key)
    }

    /// Where to start playing: the saved position, or 0 if never played or already watched.
    static func startPosition(for entry: Entry?) -> Double {
        guard let entry, entry.position < entry.duration - watchedMargin else { return 0 }
        return entry.position
    }

    /// How much of the red bar to fill under a thumbnail.
    static func fraction(for entry: Entry?) -> Double {
        guard let entry, entry.duration > 0 else { return 0 }
        if entry.position >= entry.duration - watchedMargin { return 1 }
        return entry.position / entry.duration
    }
}

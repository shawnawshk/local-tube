import Foundation
import Observation

/// Remembers where each video (keyed by path) was left off.
@Observable
final class ProgressStore {
    struct Entry: Codable, Equatable {
        var position: Double
        var duration: Double
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
        let entry = Entry(position: min(max(position, 0), duration), duration: duration)
        guard entries[url.path] != entry else { return }
        entries[url.path] = entry
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

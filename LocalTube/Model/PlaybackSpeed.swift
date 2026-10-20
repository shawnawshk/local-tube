import Foundation

/// Playback speed rules: YouTube's presets minus the slow ones (see CONTEXT.md §5).
enum PlaybackSpeed {
    static let presets: [Double] = [0.75, 1, 1.25, 1.5, 1.75, 2]
    static let range: ClosedRange<Double> = 0.75...2

    /// Clamps to the supported range and snaps to the custom slider's 0.05 grid.
    static func normalized(_ speed: Double) -> Double {
        let clamped = min(max(speed, range.lowerBound), range.upperBound)
        return (clamped * 20).rounded() / 20
    }

    /// Shift + > : the nearest preset above the current speed.
    static func faster(than speed: Double) -> Double {
        presets.first { $0 > speed + 0.001 } ?? presets.last!
    }

    /// Shift + < : the nearest preset below the current speed.
    static func slower(than speed: Double) -> Double {
        presets.last { $0 < speed - 0.001 } ?? presets.first!
    }

    static func isPreset(_ speed: Double) -> Bool {
        presets.contains { abs($0 - speed) < 0.001 }
    }

    /// "Normal" for 1, otherwise the bare number ("0.75", "1.25", "2").
    static func label(_ speed: Double) -> String {
        abs(speed - 1) < 0.001 ? "Normal" : String(format: "%g", speed)
    }
}

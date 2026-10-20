import AppKit

/// YouTube's keyboard shortcuts (see CONTEXT.md §4).
enum ShortcutAction: Equatable {
    case togglePlay
    case seek(by: Double)
    case seekToFraction(Double)
    case seekToStart
    case seekToEnd
    case frameStep(Int)
    case volume(by: Double)
    case toggleMute
    case faster
    case slower
    case toggleFullscreen
    case exitFullscreen
    case toggleTheater
    case togglePictureInPicture
    case next
    case previous

    static func from(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags) -> ShortcutAction? {
        // ⌘ / ⌃ / ⌥ combinations belong to the menus (⌘O, ⌘Q, ...).
        if !modifiers.intersection([.command, .control, .option]).isEmpty { return nil }
        let shift = modifiers.contains(.shift)

        switch keyCode {
        case 49: return .togglePlay        // space
        case 123: return .seek(by: -5)     // ←
        case 124: return .seek(by: 5)      // →
        case 126: return .volume(by: 0.05) // ↑
        case 125: return .volume(by: -0.05) // ↓
        case 115: return .seekToStart      // Home
        case 119: return .seekToEnd        // End
        case 53: return .exitFullscreen    // Esc
        default: break
        }

        guard let ch = characters?.lowercased(), ch.count == 1 else { return nil }
        if shift {
            switch ch {
            case ">": return .faster
            case "<": return .slower
            case "n": return .next
            case "p": return .previous
            default: return nil
            }
        }
        switch ch {
        case "k": return .togglePlay
        case "j": return .seek(by: -10)
        case "l": return .seek(by: 10)
        case "m": return .toggleMute
        case "f": return .toggleFullscreen
        case "t": return .toggleTheater
        case "i": return .togglePictureInPicture
        case ",": return .frameStep(-1)
        case ".": return .frameStep(1)
        default:
            if let digit = Int(ch) { return .seekToFraction(Double(digit) / 10) }
            return nil
        }
    }
}

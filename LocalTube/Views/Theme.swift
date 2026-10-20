import SwiftUI

/// YouTube dark theme colors.
enum Theme {
    static let background = Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255)    // #0F0F0F
    static let red = Color(red: 1, green: 0, blue: 0)                                  // #FF0000
    static let secondaryText = Color(red: 170 / 255, green: 170 / 255, blue: 170 / 255) // #AAAAAA
    static let menu = Color(red: 28 / 255, green: 28 / 255, blue: 28 / 255).opacity(0.92)
    static let highlight = Color.white.opacity(0.1)

    static let english = Locale(identifier: "en_US")
}

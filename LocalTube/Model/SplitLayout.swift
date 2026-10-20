import CoreGraphics

/// Where the divider between the player and the Up next list sits.
enum SplitLayout {
    static let minListWidth: CGFloat = 280
    static let minPlayerWidth: CGFloat = 480
    static let defaultListFraction = 0.3

    /// List width for its share of `available` (player + list), keeping both sides usable.
    static func listWidth(fraction: Double, available: CGFloat) -> CGFloat {
        let upper = max(minListWidth, available - minPlayerWidth)
        return min(max(CGFloat(fraction) * available, minListWidth), upper)
    }
}

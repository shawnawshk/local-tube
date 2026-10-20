import CoreGraphics

/// Sizes on the watch page. The window height is derived from these, so nothing is left empty.
enum WatchLayout {
    /// Outer padding; also the divider's width.
    static let padding: CGFloat = 24
    static let infoSpacing: CGFloat = 12

    static func playerWidth(contentWidth: CGFloat, showsList: Bool, theater: Bool, listFraction: Double) -> CGFloat {
        if theater { return contentWidth }
        let inner = contentWidth - padding * 2
        guard showsList else { return inner }
        let available = inner - padding
        return available - SplitLayout.listWidth(fraction: listFraction, available: available)
    }

    /// Height of a 16:9 player plus the info block at `contentWidth`.
    static func contentHeight(contentWidth: CGFloat, showsList: Bool, theater: Bool, listFraction: Double,
                              infoHeight: CGFloat) -> CGFloat {
        let player = playerWidth(contentWidth: contentWidth, showsList: showsList, theater: theater,
                                 listFraction: listFraction) * 9 / 16
        return (theater ? 0 : padding) + player + infoSpacing + infoHeight + padding
    }
}

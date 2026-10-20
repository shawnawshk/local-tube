import AppKit

/// Keeps the window exactly as tall as the watch page needs at its current width.
@MainActor
final class WindowFitter {
    private weak var window: NSWindow?
    /// Content height for a content width, or nil when the window may be any size.
    private var contentHeight: ((CGFloat) -> CGFloat?)?
    private var fitting = false

    func attach(_ window: NSWindow, contentHeight: @escaping (CGFloat) -> CGFloat?) {
        self.window = window
        self.contentHeight = contentHeight
        let center = NotificationCenter.default
        for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification] {
            center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fit() }
            }
        }
    }

    func fit() {
        guard !fitting, let window else { return }
        guard !window.styleMask.contains(.fullScreen), let contentHeight,
              let height = contentHeight(window.contentLayoutRect.width) else {
            window.resizeIncrements = NSSize(width: 1, height: 1) // drops the aspect lock
            return
        }
        let chromeHeight = window.frame.height - window.contentLayoutRect.height
        var frame = window.frame
        frame.size.height = (height + chromeHeight).rounded()

        // While the user drags an edge AppKit owns the frame; only keep the ratio in step.
        if !window.inLiveResize {
            if let screenHeight = window.screen?.visibleFrame.height, frame.height > screenHeight {
                frame.size = sizeFitting(height: screenHeight, chromeHeight: chromeHeight, in: window, contentHeight)
            }
            if frame.size != window.frame.size {
                frame.origin.y = window.frame.maxY - frame.height // keep the top edge in place
                fitting = true
                window.setFrame(frame, display: true)
                fitting = false
            }
        }
        window.aspectRatio = frame.size
    }

    /// Too tall for the screen: the widest frame whose content still fits `height`.
    private func sizeFitting(height: CGFloat, chromeHeight: CGFloat, in window: NSWindow,
                             _ contentHeight: (CGFloat) -> CGFloat?) -> NSSize {
        let chromeWidth = window.frame.width - window.contentLayoutRect.width
        var low = window.contentMinSize.width, high = window.contentLayoutRect.width
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if (contentHeight(mid) ?? 0) + chromeHeight <= height { low = mid } else { high = mid }
        }
        let width = low.rounded(.down)
        return NSSize(width: width + chromeWidth, height: ((contentHeight(width) ?? 0) + chromeHeight).rounded())
    }
}

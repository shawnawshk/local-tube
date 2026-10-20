import AppKit
import SwiftUI

struct RootView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        Group {
            if model.url == nil {
                EmptyStateView()
            } else {
                WatchView()
            }
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .navigationTitle(model.title ?? "LocalTube")
        .toolbar {
            if model.url != nil && !model.isFullscreen {
                ToolbarItem(placement: .primaryAction) {
                    let visible = model.showsPlaylist && !model.isTheater
                    Toggle(isOn: Binding(get: { visible }, set: { _ in model.togglePlaylist() })) {
                        Label("Up next", systemImage: "sidebar.right")
                    }
                    .toggleStyle(.button)
                    .help(visible ? "Hide Up next" : "Show Up next")
                }
            }
        }
        .background(WindowReader { model.attach(window: $0) })
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.open(url)
            return true
        }
        .alert(
            "Can't play “\(model.unsupportedFile?.lastPathComponent ?? "")”",
            isPresented: Binding(get: { model.unsupportedFile != nil }, set: { if !$0 { model.unsupportedFile = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text("LocalTube only plays mp4, mov and m4v files.")
        }
    }
}

struct EmptyStateView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.red)
            Text("Drop a video here or press ⌘O")
                .font(.system(size: 20, weight: .semibold))
            Text("mp4 · mov · m4v")
                .foregroundStyle(Theme.secondaryText)
            Button("Open…") { model.showOpenPanel() }
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// YouTube watch page: player + info on the left, Up next on the right when switched on.
struct WatchView: View {
    @Environment(PlayerModel.self) private var model

    private static let gap: CGFloat = 24
    private static let infoHeight: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let fullscreen = model.isFullscreen
            let theater = model.isTheater && !fullscreen
            let showsList = model.showsPlaylist && !fullscreen && !theater
            let padding = fullscreen ? 0 : Self.gap
            // Player + list share the width left after the outer padding and the divider.
            let available = geo.size.width - padding * 2 - Self.gap
            let listWidth = SplitLayout.listWidth(fraction: model.playlistFraction, available: available)
            let playerWidth = fullscreen || theater
                ? geo.size.width
                : showsList ? available - listWidth : geo.size.width - padding * 2
            let playerHeight = fullscreen
                ? geo.size.height
                : min(playerWidth * 9 / 16, geo.size.height - padding - Self.infoHeight)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    PlayerView()
                        .frame(width: playerWidth, height: playerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: fullscreen || theater ? 0 : 12))
                    if !fullscreen {
                        VideoInfoView()
                            .padding(.horizontal, theater ? Self.gap : 0)
                    }
                }
                if showsList {
                    SplitDivider(width: Self.gap) { x in
                        // x is the divider's center; the list starts half a divider to its right.
                        let width = geo.size.width - padding - x - Self.gap / 2
                        let clamped = SplitLayout.listWidth(fraction: Double(width / available), available: available)
                        model.setPlaylistFraction(Double(clamped / available))
                    }
                    UpNextList()
                        .frame(width: listWidth)
                }
            }
            .padding(.horizontal, fullscreen || theater ? 0 : padding)
            .padding(.top, theater ? 0 : padding)
        }
        .coordinateSpace(.named(SplitDivider.space))
        .ignoresSafeArea(edges: model.isFullscreen ? .all : [])
    }
}

/// The line between player and list; drag it to change their ratio.
struct SplitDivider: View {
    static let space = "watch"

    let width: CGFloat
    let onDrag: (CGFloat) -> Void
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        Rectangle()
            .fill(.white.opacity(hovering || dragging ? 0.3 : 0.08))
            .frame(width: 1)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .onHover { hovering = $0 }
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                .onChanged { value in
                    dragging = true
                    onDrag(value.location.x)
                }
                .onEnded { _ in dragging = false })
    }
}

/// Title + one line of file facts under the player.
struct VideoInfoView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.title ?? "")
                .font(.system(size: 20, weight: .bold))
                .lineLimit(2)
            Text(details)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var details: String {
        var parts: [String] = []
        if let folder = model.url?.deletingLastPathComponent().lastPathComponent { parts.append(folder) }
        parts.append(TimeFormat.string(model.duration))
        if let info = model.info {
            if let modified = info.modified {
                parts.append(modified.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Theme.english)))
            }
            if info.size != .zero { parts.append("\(Int(info.size.width))×\(Int(info.size.height))") }
        }
        return parts.joined(separator: " · ")
    }
}

/// Hands the hosting NSWindow to the model (fullscreen state, key event filtering).
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {}

    final class ReaderView: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}

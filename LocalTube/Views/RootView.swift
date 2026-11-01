import AppKit
import SwiftUI

@MainActor
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
        .frame(minWidth: 960, minHeight: model.url == nil ? 600 : 300)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .navigationTitle(model.title ?? "LocalTube")
        .toolbar {
            if model.url != nil && !model.isFullscreen {
                ToolbarItem(placement: .navigation) {
                    Button { model.goHome() } label: {
                        Label("Home", systemImage: "house")
                    }
                    .help("Home")
                }
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

@MainActor
struct EmptyStateView: View {
    @Environment(PlayerModel.self) private var model
    @State private var recent: [URL] = []

    var body: some View {
        let candidates = model.progress.recentlyPlayed()
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 48) {
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
                    if !recent.isEmpty { RecentGrid(urls: recent) }
                }
                .padding(32)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollIndicators(.never)
        }
        .task(id: candidates) { recent = await ProgressStore.existing(candidates, limit: RecentGrid.limit) }
    }
}

/// Videos played most recently, newest first; click one to pick up where it was left off.
@MainActor
struct RecentGrid: View {
    static let limit = 8

    @Environment(PlayerModel.self) private var model
    let urls: [URL]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Clear all") { model.progress.clearRecent() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.secondaryText)
                    .focusable(false) // keyboard navigation is on; Space must not clear the list
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 4),
                      spacing: 16) {
                ForEach(urls, id: \.self) { RecentCard(url: $0) }
            }
        }
        .frame(maxWidth: 1100)
    }
}

@MainActor
struct RecentCard: View {
    @Environment(PlayerModel.self) private var model
    let url: URL
    @State private var info: VideoInfo?
    @State private var hovering = false

    var body: some View {
        let entry = model.progress.entry(for: url)
        VStack(alignment: .leading, spacing: 4) {
            VideoThumbnail(info: info, watched: ProgressStore.fraction(for: entry))
                .aspectRatio(16 / 9, contentMode: .fit)
                .padding(.bottom, 4)
            Text(url.deletingPathExtension().lastPathComponent)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Text(details(lastPlayed: entry?.lastPlayed))
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering ? Theme.highlight : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.open(url) }
        .contextMenu { VideoMenu(url: url, canRemoveFromRecent: true) }
        .task(id: url) { info = await VideoInfoCache.shared.info(for: url) }
    }

    /// "2 hours ago · Folder"
    private func details(lastPlayed: Date?) -> String {
        var parts: [String] = []
        if let lastPlayed {
            parts.append(lastPlayed.formatted(Date.RelativeFormatStyle(presentation: .named, locale: Theme.english)))
        }
        parts.append(url.deletingLastPathComponent().lastPathComponent)
        return parts.joined(separator: " · ")
    }
}

/// YouTube watch page: player + info on the left, Up next on the right when switched on.
@MainActor
struct WatchView: View {
    @Environment(PlayerModel.self) private var model

    private static let gap = WatchLayout.padding

    var body: some View {
        GeometryReader { geo in
            let fullscreen = model.isFullscreen
            let theater = model.isTheater && !fullscreen
            let showsList = model.showsPlaylist && !fullscreen && !theater
            let padding = fullscreen ? 0 : Self.gap
            // Player + list share the width left after the outer padding and the divider.
            let available = geo.size.width - padding * 2 - Self.gap
            let listWidth = SplitLayout.listWidth(fraction: model.playlistFraction, available: available)
            let playerWidth = fullscreen
                ? geo.size.width
                : WatchLayout.playerWidth(contentWidth: geo.size.width, showsList: showsList, theater: theater,
                                          listFraction: model.playlistFraction)
            // The window is sized to fit (WindowFitter); the cap only matters mid-resize.
            let playerHeight = fullscreen ? geo.size.height : min(playerWidth * 9 / 16, geo.size.height)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: WatchLayout.infoSpacing) {
                    PlayerView()
                        .frame(width: playerWidth, height: playerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: fullscreen || theater ? 0 : 12))
                    if !fullscreen {
                        VideoInfoView()
                            .padding(.horizontal, theater ? Self.gap : 0)
                            .background(GeometryReader { info in
                                Color.clear
                                    .onAppear { model.setInfoHeight(info.size.height) }
                                    .onChange(of: info.size.height) { model.setInfoHeight($1) }
                            })
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
@MainActor
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
            .onHover { inside in
                hovering = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                .onChanged { value in
                    dragging = true
                    onDrag(value.location.x)
                }
                .onEnded { _ in dragging = false })
    }
}

/// Title + one line of file facts under the player. The folder name shows the video in Finder,
/// the way YouTube's channel name opens the channel.
@MainActor
struct VideoInfoView: View {
    @Environment(PlayerModel.self) private var model
    @State private var hoveringFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.title ?? "")
                .font(.system(size: 20, weight: .bold))
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if let url = model.url {
                    Button(url.deletingLastPathComponent().lastPathComponent) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .underline(hoveringFolder)
                    .foregroundStyle(hoveringFolder ? Color.white : Theme.secondaryText)
                    .onHover { hoveringFolder = $0 }
                    .help("Show in Finder")
                    Text(" · ")
                }
                Text(details)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Everything after the folder name.
    private var details: String {
        var parts: [String] = []
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
@MainActor
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

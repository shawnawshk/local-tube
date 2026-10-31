import AppKit
import SwiftUI

/// Right-hand list with two tabs. "Current folder": every supported video in the current folder,
/// current one highlighted. "Recent": the other videos played lately, newest first.
/// Autoplay and next / previous always follow the folder.
@MainActor
struct UpNextList: View {
    static let recentLimit = 20

    @Environment(PlayerModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Chip(title: "Current folder", isSelected: model.listTab == .folder) { model.setListTab(.folder) }
                Chip(title: "Recent", isSelected: model.listTab == .recent) { model.setListTab(.recent) }
                    .fixedSize()
            }
            switch model.listTab {
            case .folder: folderList
            case .recent: recentList
            }
        }
    }

    private var recentList: some View {
        let urls = model.progress.recent(limit: Self.recentLimit + 1)
            .filter { $0.path != model.url?.path }
            .prefix(Self.recentLimit)
        return Group {
            if urls.isEmpty {
                Text("Videos you play will show up here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(urls), id: \.self) { url in
                            UpNextRow(url: url, isCurrent: false, isRecent: true)
                                .onTapGesture { model.open(url) }
                                .contextMenu {
                                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                    Button("Remove from Recent") { model.progress.removeFromRecent(url) }
                                }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var folderList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\((model.currentIndex ?? 0) + 1) / \(model.playlist.count)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(model.playlist, id: \.self) { url in
                            UpNextRow(url: url, isCurrent: url == model.url)
                                .id(url)
                                .onTapGesture { model.open(url) }
                                .contextMenu {
                                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                }
                        }
                    }
                }
                .scrollIndicators(.never)
                .onAppear { proxy.scrollTo(model.url, anchor: .center) }
                .onChange(of: model.url) { _, url in
                    withAnimation { proxy.scrollTo(url, anchor: .center) }
                }
            }
        }
    }
}

/// YouTube's filter chips above the list.
@MainActor
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .foregroundStyle(isSelected ? .black : .white)
                .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? .white : Theme.highlight))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

@MainActor
struct UpNextRow: View {
    @Environment(PlayerModel.self) private var model
    let url: URL
    let isCurrent: Bool
    /// Recent rows say where the video lives and when it was last played, instead of when the file changed.
    var isRecent = false
    @State private var info: VideoInfo?
    @State private var hovering = false

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Theme.english
        return formatter
    }()

    var body: some View {
        let watched = ProgressStore.fraction(for: model.progress.entry(for: url))
        HStack(alignment: .top, spacing: 8) {
            VideoThumbnail(info: info, watched: watched)
                .frame(width: 168, height: 94)

            VStack(alignment: .leading, spacing: 4) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                if isRecent {
                    // Folder on its own line, like the channel name on YouTube.
                    Text(url.deletingLastPathComponent().lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                    if let lastPlayed = model.progress.entry(for: url)?.lastPlayed {
                        Text(Self.relative.localizedString(for: lastPlayed, relativeTo: Date()))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else if let modified = info?.modified {
                    Text(Self.relative.localizedString(for: modified, relativeTo: Date()))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                }
                if isCurrent {
                    Text("Now playing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isCurrent || hovering ? Theme.highlight : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .task(id: url) { info = await VideoInfoCache.shared.info(for: url) }
    }
}

/// A video's thumbnail with the duration badge and the red watched bar; fills the frame it's given.
@MainActor
struct VideoThumbnail: View {
    let info: VideoInfo?
    let watched: Double

    var body: some View {
        Color.clear
            .overlay { Thumbnail(image: info?.thumbnail) }
            .overlay(alignment: .bottomTrailing) {
                if let info {
                    Text(TimeFormat.string(info.duration))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.8)))
                        .padding(4)
                        .padding(.bottom, watched > 0 ? 4 : 0)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if watched > 0 {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.gray.opacity(0.6))
                        Rectangle().fill(Theme.red).scaleEffect(x: watched, anchor: .leading)
                    }
                    .frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

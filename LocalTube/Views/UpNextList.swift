import SwiftUI

/// Right-hand list: every supported video in the current folder, current one highlighted.
@MainActor
struct UpNextList: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.url?.deletingLastPathComponent().lastPathComponent ?? "")
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                Text("\((model.currentIndex ?? 0) + 1) / \(model.playlist.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(model.playlist, id: \.self) { url in
                            UpNextRow(url: url, isCurrent: url == model.url)
                                .id(url)
                                .onTapGesture { model.open(url) }
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

@MainActor
struct UpNextRow: View {
    @Environment(PlayerModel.self) private var model
    let url: URL
    let isCurrent: Bool
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
            ZStack(alignment: .bottomTrailing) {
                Thumbnail(image: info?.thumbnail)
                    .frame(width: 168, height: 94)
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
                        Rectangle().fill(Theme.red).frame(width: 168 * watched)
                    }
                    .frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                if let modified = info?.modified {
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

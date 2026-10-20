import AVFoundation
import AppKit
import SwiftUI

/// Video + everything layered on it: feedback, autoplay card, control bar, settings panel.
struct PlayerView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            VideoSurface()
            OSDView()
                .allowsHitTesting(false)

            if model.countdownStart != nil {
                AutoplayCountdown()
            } else if model.hasEnded {
                ReplayButton()
            }

            ControlBar()
                .opacity(model.showsControls ? 1 : 0)
                .allowsHitTesting(model.showsControls)
                .animation(.easeOut(duration: 0.2), value: model.showsControls)

            if model.isSettingsOpen {
                SpeedPanel()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                    .padding(.bottom, 60)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                model.isMouseInPlayer = true
                model.noteActivity()
            case .ended:
                model.mouseLeftPlayer()
            }
        }
    }
}

/// AVPlayerLayer host. Click toggles play, double click toggles fullscreen (YouTube behavior).
struct VideoSurface: NSViewRepresentable {
    @Environment(PlayerModel.self) private var model

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = model.player
        model.attach(playerLayer: view.playerLayer)
        let model = model
        view.onClick = { clickCount in
            if model.isSettingsOpen {
                model.isSettingsOpen = false
            } else if clickCount == 1 {
                model.togglePlay()
            } else if clickCount == 2 {
                // The first click already toggled play; undo it, then go fullscreen.
                model.togglePlay(feedback: false)
                model.toggleFullscreen()
            }
        }
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {}

    final class PlayerLayerView: NSView {
        let playerLayer = AVPlayerLayer()
        var onClick: ((Int) -> Void)?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspect
        }

        required init?(coder: NSCoder) { fatalError() }

        override func makeBackingLayer() -> CALayer { playerLayer }

        override func mouseDown(with event: NSEvent) {
            onClick?(event.clickCount)
        }
    }
}

struct ReplayButton: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        Button { model.play() } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 30, weight: .semibold))
                .frame(width: 72, height: 72)
                .background(Circle().fill(.black.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help("Replay")
    }
}

/// YouTube's end-of-video card: next video, a countdown ring, Cancel / Play now.
struct AutoplayCountdown: View {
    @Environment(PlayerModel.self) private var model
    @State private var nextInfo: VideoInfo?

    var body: some View {
        let next = model.nextURL
        GeometryReader { geo in
            // Shrink the thumbnail so the card fits above the control bar in small windows.
            let thumbHeight = max(60, min(180, geo.size.height - 230))
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(model.countdownStart ?? context.date)
                let remaining = max(PlayerModel.countdownSeconds - elapsed, 0)
                VStack(spacing: 14) {
                    Text("Up next in \(Int(remaining.rounded(.up)))")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondaryText)
                    Button { model.playNext() } label: {
                        ZStack {
                            Thumbnail(image: nextInfo?.thumbnail)
                                .frame(width: thumbHeight * 16 / 9, height: thumbHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 64, height: 64)
                            Circle()
                                .trim(from: 0, to: min(elapsed / PlayerModel.countdownSeconds, 1))
                                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 64, height: 64)
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    Text(next?.deletingPathExtension().lastPathComponent ?? "")
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    HStack(spacing: 12) {
                        Button { model.cancelCountdown() } label: {
                            Text("Cancel").frame(width: 110, height: 36)
                                .background(Capsule().fill(.white.opacity(0.15)))
                        }
                        Button { model.playNext() } label: {
                            Text("Play now").frame(width: 110, height: 36)
                                .foregroundStyle(.black)
                                .background(Capsule().fill(.white))
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 48)
            }
        }
        .background(Color.black.opacity(0.75))
        .task(id: next) {
            if let next { nextInfo = await VideoInfoCache.shared.info(for: next) }
        }
    }
}

/// Center icon on play/pause, side "5 seconds" on seek, top pill for volume / speed.
struct OSDView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        ZStack {
            if let osd = model.osd {
                content(for: osd.kind)
                    .id(osd.id)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.25), value: model.osd)
    }

    @ViewBuilder
    private func content(for kind: OSD.Kind) -> some View {
        switch kind {
        case .play:
            centerIcon("play.fill")
        case .pause:
            centerIcon("pause.fill")
        case .seek(let delta):
            HStack(spacing: 6) {
                Image(systemName: delta < 0 ? "backward.fill" : "forward.fill")
                Text("\(Int(abs(delta))) seconds")
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(.black.opacity(0.6)))
            .frame(maxWidth: .infinity, alignment: delta < 0 ? .leading : .trailing)
            .padding(.horizontal, 60)
        case .volume(let value):
            VStack {
                pill(value == 0 ? "Muted" : "\(Int((value * 100).rounded()))%")
                Spacer()
                centerIcon(value == 0 ? "speaker.slash.fill" : value < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill")
                Spacer()
            }
        case .speed(let value):
            VStack {
                pill("\(String(format: "%g", value))x")
                Spacer()
            }
        }
    }

    private func centerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 26))
            .frame(width: 64, height: 64)
            .background(Circle().fill(.black.opacity(0.6)))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.6)))
            .padding(.top, 40)
    }
}

struct Thumbnail: View {
    let image: CGImage?

    var body: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(.white.opacity(0.08))
        }
    }
}

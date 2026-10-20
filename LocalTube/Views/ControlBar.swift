import SwiftUI

/// YouTube control bar: progress bar on top, buttons below, dark gradient behind.
@MainActor
struct ControlBar: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ProgressBar()
            HStack(spacing: 2) {
                BarButton(symbol: model.hasEnded ? "arrow.counterclockwise" : model.isPlaying ? "pause.fill" : "play.fill",
                          help: model.hasEnded ? "Replay" : model.isPlaying ? "Pause (k)" : "Play (k)") {
                    model.togglePlay(feedback: false)
                }
                BarButton(symbol: "forward.end.fill", help: "Next (SHIFT+n)") { model.playNext() }
                    .disabled(model.nextURL == nil)
                    .opacity(model.nextURL == nil ? 0.4 : 1)
                VolumeControl()
                Text("\(TimeFormat.string(model.currentTime)) / \(TimeFormat.string(model.duration))")
                    .font(.system(size: 13).monospacedDigit())
                    .padding(.leading, 8)
                Spacer()
                AutoplayToggle()
                BarButton(symbol: "gearshape.fill", help: "Settings") { model.isSettingsOpen.toggle() }
                BarButton(symbol: model.isPictureInPicture ? "pip.exit" : "pip.enter", help: "Picture-in-picture (i)") {
                    model.togglePictureInPicture()
                }
                if !model.isFullscreen {
                    BarButton(symbol: model.isTheater ? "rectangle.inset.filled" : "rectangle.ratio.16.to.9",
                              help: model.isTheater ? "Default view (t)" : "Theater mode (t)") {
                        model.toggleTheater()
                    }
                }
                BarButton(symbol: model.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                          help: model.isFullscreen ? "Exit full screen (f)" : "Full screen (f)") {
                    model.toggleFullscreen()
                }
            }
            .frame(height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
        .foregroundStyle(.white)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
                .allowsHitTesting(false)
        }
    }
}

@MainActor
struct BarButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }
}

/// Speaker button; the slider slides out on hover, like YouTube.
@MainActor
struct VolumeControl: View {
    @Environment(PlayerModel.self) private var model
    @State private var hovering = false

    var body: some View {
        let shown = model.isMuted ? 0 : model.volume
        HStack(spacing: 4) {
            BarButton(symbol: shown == 0 ? "speaker.slash.fill" : shown < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill",
                      help: model.isMuted ? "Unmute (m)" : "Mute (m)") {
                model.toggleMute()
            }
            if hovering {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3)).frame(height: 3)
                        Capsule().fill(.white).frame(width: geo.size.width * shown, height: 3)
                        Circle().fill(.white).frame(width: 12, height: 12)
                            .offset(x: geo.size.width * shown - 6)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        model.setVolume(value.location.x / geo.size.width)
                    })
                }
                .frame(width: 60)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(height: 40)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) { hovering = inside }
        }
    }
}

@MainActor
struct AutoplayToggle: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        Button { model.setAutoplay(!model.autoplay) } label: {
            ZStack(alignment: model.autoplay ? .trailing : .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 14)
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: model.autoplay ? "play.fill" : "pause.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.black)
                    }
            }
            .frame(width: 44, height: 40)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: model.autoplay)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(model.autoplay ? "Autoplay is on" : "Autoplay is off")
    }
}

/// Red played part, lighter hover part, scrubber dot and hover preview frame.
@MainActor
struct ProgressBar: View {
    @Environment(PlayerModel.self) private var model
    @State private var hoverX: CGFloat?
    @State private var dragging = false
    @State private var previewImage: CGImage?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let played = model.duration > 0 ? CGFloat(model.currentTime / model.duration) * width : 0
            let expanded = hoverX != nil || dragging

            ZStack(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.2))
                if let hoverX { Rectangle().fill(.white.opacity(0.4)).frame(width: hoverX) }
                Rectangle().fill(Theme.red).frame(width: played)
            }
            .frame(height: expanded ? 5 : 3)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Theme.red)
                    .frame(width: 13, height: 13)
                    .offset(x: played - 6.5)
                    .opacity(expanded ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): hoverX = min(max(point.x, 0), width)
                case .ended: if !dragging { hoverX = nil }
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragging = true
                    let x = min(max(value.location.x, 0), width)
                    hoverX = x
                    model.seek(to: Double(x / width) * model.duration)
                }
                .onEnded { _ in
                    dragging = false
                    hoverX = nil
                })
            .overlay(alignment: .bottomLeading) {
                if let hoverX, model.duration > 0 {
                    HoverPreview(image: previewImage, time: Double(hoverX / width) * model.duration)
                        .offset(x: min(max(hoverX - HoverPreview.width / 2, 0), width - HoverPreview.width), y: -24)
                        .allowsHitTesting(false)
                }
            }
            .task(id: bucket(width: width)) {
                guard let bucket = bucket(width: width), let preview = model.preview else { return }
                previewImage = await preview.image(bucket: bucket)
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.1), value: hoverX != nil || dragging)
    }

    private func bucket(width: CGFloat) -> Int? {
        guard let hoverX, width > 0 else { return nil }
        return Int((hoverX / width * CGFloat(PreviewGenerator.buckets)).rounded())
    }
}

@MainActor
struct HoverPreview: View {
    static let width: CGFloat = 160
    let image: CGImage?
    let time: Double

    var body: some View {
        VStack(spacing: 6) {
            Thumbnail(image: image)
                .frame(width: Self.width, height: Self.width * 9 / 16)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
            Text(TimeFormat.string(time))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .shadow(radius: 2)
        }
        .frame(width: Self.width)
    }
}

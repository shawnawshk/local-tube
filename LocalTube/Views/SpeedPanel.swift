import SwiftUI

/// The gear menu. Like YouTube: "Playback speed  Normal ›", then the speed list with a Custom slider.
@MainActor
struct SpeedPanel: View {
    @Environment(PlayerModel.self) private var model
    @State private var showingSpeeds = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingSpeeds {
                speedList
            } else {
                row {
                    Image(systemName: "speedometer").frame(width: 24)
                    Text("Playback speed")
                    Spacer()
                    Text(PlaybackSpeed.isPreset(model.speed)
                         ? PlaybackSpeed.label(model.speed)
                         : "Custom (\(PlaybackSpeed.label(model.speed)))")
                    Image(systemName: "chevron.right").font(.system(size: 11))
                } action: {
                    showingSpeeds = true
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 260)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.menu))
    }

    private var speedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            row {
                Image(systemName: "chevron.left").font(.system(size: 11))
                Text("Playback speed")
                Spacer()
            } action: {
                showingSpeeds = false
            }
            Divider().overlay(.white.opacity(0.2)).padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Custom")
                    Spacer()
                    Text(String(format: "%gx", model.speed))
                        .monospacedDigit()
                }
                Slider(value: Binding(get: { model.speed }, set: { model.setSpeed($0) }),
                       in: PlaybackSpeed.range, step: 0.05)
                    .tint(.white)
                    .controlSize(.small)
                    .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            ForEach(PlaybackSpeed.presets, id: \.self) { preset in
                row {
                    Image(systemName: "checkmark")
                        .frame(width: 24)
                        .opacity(abs(model.speed - preset) < 0.001 ? 1 : 0)
                    Text(PlaybackSpeed.label(preset))
                    Spacer()
                } action: {
                    model.setSpeed(preset)
                }
            }
        }
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 16)
                .frame(height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowStyle())
        .focusable(false)
    }
}

private struct MenuRowStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hovering || configuration.isPressed ? Color.white.opacity(0.1) : .clear)
            .onHover { hovering = $0 }
    }
}

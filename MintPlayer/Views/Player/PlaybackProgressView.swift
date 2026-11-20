import SwiftUI

struct PlaybackProgressView: View {
    enum Style {
        case bar
        case lyrics
    }

    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var progress: PlaybackProgress
    @GestureState private var scrubTime: TimeInterval? = nil
    @State private var isHovering = false

    private let duration: TimeInterval
    private let style: Style
    private let onSeek: (TimeInterval) -> Void

    init(player: AudioPlayer, songID: Song.ID?, style: Style) {
        progress = player.progress
        duration = songID == nil ? 0 : player.duration
        self.style = style
        onSeek = { time in
            guard let songID, player.currentSong?.id == songID,
                  player.duration.isFinite, player.duration > 0 else { return }
            player.seek(to: time)
        }
    }

    private var isEnabled: Bool { duration.isFinite && duration > 0 }
    private var range: ClosedRange<TimeInterval> { 0...(isEnabled ? duration : 1) }
    private var displayedTime: TimeInterval {
        isEnabled ? min(max(scrubTime ?? progress.time, 0), duration) : 0
    }

    var body: some View {
        if style == .lyrics {
            VStack(spacing: 8) {
                slider
                    .frame(height: 18)

                HStack {
                    Text(timeText(displayedTime))
                    Spacer()
                    Text(timeText(duration))
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            slider
                .frame(height: 5)
        }
    }

    private var slider: some View {
        let trackHeight: CGFloat = style == .lyrics ? 7 : 3
        let knobDiameter: CGFloat = style == .lyrics ? 15 : 9
        let hitHeight: CGFloat = style == .lyrics ? 22 : 14
        let showsKnob = isEnabled && (isHovering || scrubTime != nil)

        return GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progressWidth = width * CGFloat(displayedTime / range.upperBound)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(style == .lyrics ? Color.white.opacity(0.22) : Color.primary.opacity(0.16))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(style == .lyrics ? Color.white.opacity(0.74) : Color.primary.opacity(0.65))
                    .frame(width: max(progressWidth, progressWidth > 0 ? trackHeight : 0), height: trackHeight)

                Circle()
                    .fill(style == .lyrics || colorScheme == .dark ? Color.white : Color.black)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(
                        color: .black.opacity(style == .lyrics ? 0.22 : 0.18),
                        radius: style == .lyrics ? 4 : 2,
                        y: style == .lyrics ? 2 : 1
                    )
                    .position(x: progressWidth, y: hitHeight / 2)
                    .opacity(showsKnob ? 1 : 0)
            }
            .frame(height: hitHeight)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($scrubTime) { gesture, scrubTime, _ in
                        scrubTime = time(at: gesture.location.x, width: width)
                    }
                    .onEnded { gesture in
                        onSeek(time(at: gesture.location.x, width: width))
                    },
                including: isEnabled ? .all : .none
            )
        }
        .frame(height: hitHeight)
        .focusable(isEnabled)
        .onMoveCommand { direction in
            switch direction {
            case .left, .down: adjust(by: -5)
            case .right, .up: adjust(by: 5)
            default: break
            }
        }
        .accessibilityRepresentation {
            Slider(value: Binding(get: { displayedTime }, set: onSeek), in: range) {
                Text(settings.text(.playbackPosition))
            }
            .accessibilityValue(String(format: settings.text(.positionValue), timeText(displayedTime), timeText(duration)))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjust(by: 5)
                case .decrement: adjust(by: -5)
                @unknown default: break
                }
            }
            .disabled(!isEnabled)
        }
    }

    private func time(at location: CGFloat, width: CGFloat) -> TimeInterval {
        TimeInterval(min(max(location / width, 0), 1)) * range.upperBound
    }

    private func adjust(by seconds: TimeInterval) {
        guard isEnabled else { return }
        onSeek(min(max(displayedTime + seconds, 0), duration))
    }

    private func timeText(_ time: TimeInterval) -> String {
        let seconds = time.isFinite ? Int(max(time, 0)) : 0
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

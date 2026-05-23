import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @State private var isQueuePresented = false
    @State private var isVolumePresented = false

    var onArtworkClick: () -> Void = {}

    private let artworkSize: CGFloat = 38
    private let barHeight: CGFloat = 50
    private let infoMinWidth: CGFloat = 190
    private let infoIdealWidth: CGFloat = 360
    private let infoMaxWidth: CGFloat = 620

    var body: some View {
        HStack(spacing: 12) {
            transportControls

            Spacer(minLength: 8)

            nowPlaying
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Spacer(minLength: 8)

            utilityControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
        .modifier(FloatingPlayerGlassSurface())
    }

    private var transportControls: some View {
        HStack(spacing: 13) {
            PlayerIconButton(
                systemName: "shuffle",
                isActive: audioPlayer.isShuffleEnabled,
                usesSecondaryInactiveColor: true
            ) {
                audioPlayer.toggleShuffle()
            }
            PlayerIconButton(systemName: "backward.fill") {
                audioPlayer.previous()
            }
            Button(action: togglePlay) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(MintPlainIconButtonStyle())
            PlayerIconButton(systemName: "forward.fill") {
                audioPlayer.next()
            }
            PlayerIconButton(
                systemName: "repeat",
                isActive: audioPlayer.isRepeatEnabled,
                usesSecondaryInactiveColor: true
            ) {
                audioPlayer.toggleRepeat()
            }
        }
    }

    @ViewBuilder
    private var nowPlaying: some View {
        if let currentSong = audioPlayer.currentSong {
            HStack(alignment: .center, spacing: 12) {
                artwork(for: currentSong)

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentSong.title)
                        .font(.callout.weight(.bold))
                        .lineLimit(1)

                    Text("\(currentSong.artist) - \(currentSong.album)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    progressBar
                        .padding(.top, 2)
                }
                .frame(minWidth: infoMinWidth, idealWidth: infoIdealWidth, maxWidth: infoMaxWidth, alignment: .leading)
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: artworkSize, height: artworkSize)

                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.text(.notPlaying))
                        .font(.callout.weight(.bold))
                        .lineLimit(1)
                    Text(settings.text(.chooseSong))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    progressBar
                        .padding(.top, 2)
                }
                .frame(minWidth: infoMinWidth, idealWidth: infoIdealWidth, maxWidth: infoMaxWidth, alignment: .leading)
            }
        }
    }

    private var utilityControls: some View {
        HStack(spacing: 14) {
            PlayerIconButton(
                systemName: currentSongIsFavorite ? "heart.fill" : "heart",
                isActive: currentSongIsFavorite,
                isDisabled: audioPlayer.currentSong == nil
            ) {
                toggleCurrentSongFavorite()
            }
            .help(currentSongIsFavorite ? settings.text(.removeFromFavorites) : settings.text(.addToFavorites))

            Button(action: { isQueuePresented.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(MintPlainIconButtonStyle())
            .help(settings.text(.upNext))
            .popover(isPresented: $isQueuePresented, arrowEdge: .bottom) {
                QueueView(isVisible: $isQueuePresented)
                    .frame(width: 380, height: 520)
            }
            Button(action: { isVolumePresented.toggle() }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(MintPlainIconButtonStyle())
            .help(settings.text(.volume))
            .popover(isPresented: $isVolumePresented, arrowEdge: .bottom) {
                volumeControl
                    .frame(width: 220)
                    .padding(14)
            }
        }
    }

    private var progressBar: some View {
        HoverProgressSlider(
            value: Binding(
                get: { min(audioPlayer.currentTime, max(audioPlayer.duration, 0)) },
                set: { audioPlayer.seek(to: $0) }
            ),
            range: 0...max(audioPlayer.duration, 1),
            isEnabled: audioPlayer.currentSong != nil
        )
        .frame(height: 5)
        .opacity(audioPlayer.currentSong == nil ? 0.45 : 1)
    }

    private var volumeControl: some View {
        HStack(spacing: 10) {
            Image(systemName: volumeIcon)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { audioPlayer.volume },
                    set: { audioPlayer.setVolume($0) }
                ),
                in: 0...1
            )
            .controlSize(.small)
        }
    }

    private var volumeIcon: String {
        switch audioPlayer.volume {
        case 0:
            return "speaker.slash.fill"
        case ..<0.35:
            return "speaker.wave.1.fill"
        case ..<0.7:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    private var currentSongIsFavorite: Bool {
        guard let song = audioPlayer.currentSong else { return false }
        return musicLibrary.song(withId: song.id)?.isFavorite ?? song.isFavorite
    }

    private func artwork(for song: Song) -> some View {
        Button(action: onArtworkClick) {
            ArtworkImage(path: song.coverPath, cornerRadius: 8)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(MintContentButtonStyle(cornerRadius: 8, hoverOutset: 0))
        .help(settings.text(.showLyrics))
    }

    private func togglePlay() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.resume()
        }
    }

    private func toggleCurrentSongFavorite() {
        guard let song = audioPlayer.currentSong else { return }
        musicLibrary.toggleFavorite(for: song.id)
    }
}

private struct FloatingPlayerGlassSurface: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 25, style: .continuous)

    func body(content: Content) -> some View {
        GlassEffectContainer {
            content
                .contentShape(shape)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay {
                    shape
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 14)
        }
    }
}

private struct PlayerIconButton: View {
    let systemName: String
    var isActive = false
    var isDisabled = false
    var usesSecondaryInactiveColor = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(width: 22, height: 24)
        }
        .buttonStyle(
            PlayerBarIconButtonStyle(
                isActive: isActive,
                inactiveColor: usesSecondaryInactiveColor ? .secondary : .primary
            )
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1)
    }
}

private struct PlayerBarIconButtonStyle: ButtonStyle {
    let isActive: Bool
    let inactiveColor: Color
    private let hoverSize: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(
            configuration: configuration,
            isActive: isActive,
            inactiveColor: inactiveColor,
            hoverSize: hoverSize
        )
    }

    private struct ButtonBody: View {
        let configuration: Configuration
        let isActive: Bool
        let inactiveColor: Color
        let hoverSize: CGFloat
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isActive ? MintTheme.accent : inactiveColor)
                .background {
                    if configuration.isPressed {
                        Circle().fill(MintTheme.pressedFill)
                            .frame(width: hoverSize, height: hoverSize)
                    } else if isHovered {
                        Circle().fill(MintTheme.hoverFill)
                            .frame(width: hoverSize, height: hoverSize)
                    }
                }
                .opacity(configuration.isPressed ? 0.78 : 1)
                .contentShape(Circle())
                .onHover { isHovered = $0 }
        }
    }
}

private struct HoverProgressSlider: View {
    @Binding var value: TimeInterval
    let range: ClosedRange<TimeInterval>
    let isEnabled: Bool

    @State private var isHovering = false
    @State private var isDragging = false

    private let trackHeight: CGFloat = 3
    private let knobDiameter: CGFloat = 9
    private let hitHeight: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progress = normalizedProgress
            let progressWidth = width * progress
            let showsKnob = isEnabled && (isHovering || isDragging)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.16))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(MintTheme.accent)
                    .frame(width: max(progressWidth, progress > 0 ? trackHeight : 0), height: trackHeight)

                Circle()
                    .fill(MintTheme.accent)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 0.75)
                    }
                    .position(x: progressWidth, y: hitHeight / 2)
                    .opacity(showsKnob ? 1 : 0)
            }
            .frame(height: hitHeight)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gestureValue in
                        guard isEnabled else { return }
                        isDragging = true
                        updateValue(locationX: gestureValue.location.x, width: width)
                    }
                    .onEnded { gestureValue in
                        guard isEnabled else { return }
                        updateValue(locationX: gestureValue.location.x, width: width)
                        isDragging = false
                    }
            )
        }
        .frame(height: hitHeight)
    }

    private var normalizedProgress: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }

        let clampedValue = min(max(value, range.lowerBound), range.upperBound)
        return CGFloat((clampedValue - range.lowerBound) / span)
    }

    private func updateValue(locationX: CGFloat, width: CGFloat) {
        let progress = min(max(locationX / max(width, 1), 0), 1)
        let span = range.upperBound - range.lowerBound
        value = range.lowerBound + TimeInterval(progress) * span
    }
}

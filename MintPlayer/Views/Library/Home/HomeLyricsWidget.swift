import SwiftUI

struct HomeLyricsWidget: View {
    let onShowLyrics: () -> Void

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    @State private var lyricsState: LyricsLoadState = .loading
    @State private var loadedRequest: LyricsRequest?

    var body: some View {
        Button(action: onShowLyrics) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    GeometryReader { geometry in
                        ArtworkImage(
                            path: audioPlayer.currentSong?.coverPath,
                            cornerRadius: 0,
                            targetSize: geometry.size,
                            crossfadeChanges: true
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(1.2)
                        .blur(radius: 18)
                        .overlay(Color.black.opacity(0.28))
                        .clipped()
                        .transaction { transaction in
                            if reducesMotion { transaction.disablesAnimations = true }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(MintContentButtonStyle(cornerRadius: 20, hoverOutset: 0))
        .disabled(audioPlayer.currentSong == nil)
        .help(settings.text(.showFullScreenLyrics))
        .accessibilityLabel(settings.text(.showFullScreenLyrics))
        .accessibilityValue(lyricsAccessibilityValue)
        .environment(\.colorScheme, .dark)
        .task(id: lyricsRequest) {
            guard let song = audioPlayer.currentSong, let request = lyricsRequest else {
                lyricsState = .loading
                loadedRequest = nil
                return
            }
            let fileURL = settings.lyricsFileURL(for: song)
            let result = await Task.detached(priority: .userInitiated) {
                LyricsService.loadLyrics(
                    for: song,
                    fileURL: fileURL,
                    timingOffset: request.offset,
                    encoding: request.encoding
                )
            }.value
            guard !Task.isCancelled else { return }
            lyricsState = result
            loadedRequest = request
        }
    }

    @ViewBuilder
    private var content: some View {
        if audioPlayer.currentSong == nil {
            message(title: settings.text(.lyrics), detail: settings.text(.lyricsWidgetIdle))
        } else if loadedRequest != lyricsRequest {
            loading
        } else {
            switch lyricsState {
            case .loading:
                loading
            case .synced(let lines):
                SyncedLyricsView(lines: lines, style: .widget)
                    .padding(.horizontal, 16)
                    .mask(edgeFade)
            case .plainText(let lines):
                if lines.isEmpty {
                    message(title: settings.text(.noLyrics), detail: settings.text(.emptyLyrics))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                    }
                    .mask(edgeFade)
                }
            case .missing:
                message(title: settings.text(.noLyrics), detail: settings.text(.noLyricsFile))
            case .failed(let detail):
                message(title: settings.text(.lyricsUnavailable), detail: detail)
            }
        }
    }

    private var loading: some View {
        ProgressView(settings.text(.lyricsLoading))
            .controlSize(.small)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
    }

    private var lyricsAccessibilityValue: String {
        guard audioPlayer.currentSong != nil else { return settings.text(.lyricsWidgetIdle) }
        guard loadedRequest == lyricsRequest else { return settings.text(.lyricsLoading) }
        switch lyricsState {
        case .loading: return settings.text(.lyricsLoading)
        case .synced(let lines):
            return lines.last(where: { $0.time <= audioPlayer.currentTime })?.text ?? settings.text(.lyrics)
        case .plainText(let lines): return lines.first ?? settings.text(.noLyrics)
        case .missing: return settings.text(.noLyrics)
        case .failed: return settings.text(.lyricsUnavailable)
        }
    }

    private var edgeFade: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .white, location: 0.14),
            .init(color: .white, location: 0.86),
            .init(color: .clear, location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    private func message(title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "text.quote")
                .font(.system(size: 20))
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(16)
        .help(detail)
        .accessibilityElement(children: .combine)
    }

    private struct LyricsRequest: Hashable {
        let songID: Song.ID
        let path: String
        let offset: TimeInterval
        let encoding: LyricsTextEncoding
        let language: AppLanguage
    }

    private var lyricsRequest: LyricsRequest? {
        guard let song = audioPlayer.currentSong else { return nil }
        return LyricsRequest(
            songID: song.id,
            path: settings.lyricsFileURL(for: song)?.path ?? song.path,
            offset: settings.lyricsTimingOffset(for: song),
            encoding: settings.lyricsEncoding(for: song),
            language: settings.effectiveLanguage
        )
    }
}

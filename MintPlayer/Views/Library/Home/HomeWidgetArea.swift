import SwiftUI

struct HomeWidgetArea: View {
    @EnvironmentObject private var settings: SettingsManager

    let suggestedSong: Song?
    let onShowLyrics: () -> Void

    var body: some View {
        HomeWidgetGridLayout {
            ForEach(HomeWidgetGrid.widgets) { kind in
                HomeWidgetContent(kind: kind, suggestedSong: suggestedSong, onShowLyrics: onShowLyrics)
                    .frame(width: kind.size.width, height: kind.size.height)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(settings.text(kind.titleKey))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeWidgetGridLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.width ?? HomeWidgetGrid.length(8)
        let width = proposedWidth.isFinite ? proposedWidth : HomeWidgetGrid.length(8)
        let placements = HomeWidgetGrid.placements(availableWidth: width)
        let rows = max(2, placements.map { $0.row + $0.kind.rowSpan }.max() ?? 0)
        return CGSize(width: width, height: HomeWidgetGrid.length(rows))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = HomeWidgetGrid.placements(availableWidth: bounds.width)
        for (placement, subview) in zip(placements, subviews) {
            subview.place(
                at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.kind.size)
            )
        }
    }
}

private enum HomeWidgetKind: Identifiable, Hashable {
    case favorites
    case shuffle
    case resume
    case lyrics

    var id: Self { self }
    var columnSpan: Int { self == .resume ? 4 : 2 }
    var rowSpan: Int { self == .resume || self == .lyrics ? 2 : 1 }
    var cornerRadius: CGFloat { 20 }
    var size: CGSize { CGSize(width: HomeWidgetGrid.length(columnSpan), height: HomeWidgetGrid.length(rowSpan)) }

    var titleKey: L10n.Key {
        switch self {
        case .favorites: return .favorites
        case .shuffle: return .shuffle
        case .resume: return .resumePlayback
        case .lyrics: return .lyrics
        }
    }
}

private struct HomeWidgetPlacement {
    let kind: HomeWidgetKind
    let column: Int
    let row: Int

    var origin: CGPoint { CGPoint(x: CGFloat(column) * HomeWidgetGrid.pitch, y: CGFloat(row) * HomeWidgetGrid.pitch) }
}

private enum HomeWidgetGrid {
    static let widgets: [HomeWidgetKind] = [.favorites, .shuffle, .resume, .lyrics]
    static let unit: CGFloat = 75
    static let spacing: CGFloat = 16
    static let pitch = unit + spacing

    static func placements(availableWidth: CGFloat) -> [HomeWidgetPlacement] {
        let fitsLyricsOnFirstRow = availableWidth >= length(8)
        return widgets.map { kind in
            switch kind {
            case .favorites: return HomeWidgetPlacement(kind: kind, column: 0, row: 0)
            case .shuffle: return HomeWidgetPlacement(kind: kind, column: 0, row: 1)
            case .resume: return HomeWidgetPlacement(kind: kind, column: 2, row: 0)
            case .lyrics:
                return HomeWidgetPlacement(kind: kind, column: fitsLyricsOnFirstRow ? 6 : 0, row: fitsLyricsOnFirstRow ? 0 : 2)
            }
        }
    }

    static func length(_ span: Int) -> CGFloat { CGFloat(span) * pitch - spacing }
}

private struct HomeWidgetContent: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    let kind: HomeWidgetKind
    let suggestedSong: Song?
    let onShowLyrics: () -> Void

    var body: some View {
        Group {
            switch kind {
            case .resume:
                HomeListeningWidget(suggestedSong: suggestedSong)
            case .lyrics:
                HomeLyricsWidget(onShowLyrics: onShowLyrics)
            case .favorites, .shuffle:
                quickAction
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: kind.cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: kind.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: kind.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var songs: [Song] { kind == .favorites ? musicLibrary.favoriteSongs : musicLibrary.songs }

    private var detail: String {
        if songs.isEmpty { return settings.text(kind == .favorites ? .noFavoriteSongs : .noSongsYet) }
        return settings.text(kind == .favorites ? .favoriteWidgetSubtitle : .shuffleWidgetSubtitle)
    }

    private var quickAction: some View {
        Button {
            if kind == .favorites {
                audioPlayer.play(songs: songs)
            } else {
                audioPlayer.shuffle(songs: songs)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind == .favorites ? "heart" : "shuffle")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 43, height: 43)
                    .background(Color.primary.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.text(kind.titleKey))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(width: kind.size.width, height: kind.size.height, alignment: .leading)
        }
        .buttonStyle(MintContentButtonStyle(cornerRadius: kind.cornerRadius, hoverOutset: 0))
        .disabled(songs.isEmpty)
        .opacity(songs.isEmpty ? 0.55 : 1)
        .help(detail)
    }
}

private struct HomeListeningWidget: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @State private var pausedTime: TimeInterval = 0
    let suggestedSong: Song?

    private var song: Song? {
        musicLibrary.songs.isEmpty ? nil : (audioPlayer.currentSong ?? suggestedSong)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ArtworkImage(path: song?.coverPath, cornerRadius: 9, targetSize: CGSize(width: 134, height: 134), crossfadeChanges: true)
                .frame(width: 134, height: 134)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song?.title ?? settings.text(.resumePlayback))
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(2)
                    Text(song.map { "\($0.artist) - \($0.album)" } ?? settings.text(.noSongsYet))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button {
                    guard let song else { return }
                    if audioPlayer.isPlaying {
                        audioPlayer.next()
                    } else if audioPlayer.currentSong != nil {
                        audioPlayer.resume()
                    } else {
                        audioPlayer.play(song: song, in: musicLibrary.songs)
                    }
                } label: {
                    ZStack {
                        HStack(spacing: 8) {
                            Image(systemName: audioPlayer.isPlaying ? "forward.fill" : "play.fill")
                                .font(.system(size: 20))
                                .frame(width: 20, height: 20)
                            Text(buttonTitle)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .id(buttonTitle)
                        .transition(.blurReplace)
                    }
                    .lineLimit(1)
                    .frame(width: 114, height: 43)
                    .background(Color.primary.opacity(0.10), in: Capsule())
                    .animation(reducesMotion ? nil : .easeInOut(duration: 0.22), value: buttonTitle)
                }
                .buttonStyle(MintContentButtonStyle(cornerRadius: 21.5, hoverOutset: 0))
                .fixedSize()
                .disabled(song == nil || musicLibrary.songs.isEmpty)
                .help(song == nil ? settings.text(.noSongsYet) : (audioPlayer.isPlaying ? buttonTitle : playbackCaption))
                .accessibilityLabel(buttonTitle)
            }
            .frame(maxWidth: .infinity, minHeight: 134, maxHeight: 134, alignment: .topLeading)
        }
        .padding(16)
        .frame(width: HomeWidgetKind.resume.size.width, height: HomeWidgetKind.resume.size.height, alignment: .leading)
        .onReceive(audioPlayer.progress.$time) { time in
            if !audioPlayer.isPlaying {
                pausedTime = time
            }
        }
        .onChange(of: audioPlayer.isPlaying) { _, isPlaying in
            if !isPlaying {
                pausedTime = audioPlayer.progress.time
            }
        }
    }

    private var buttonTitle: String {
        settings.text(audioPlayer.isPlaying ? .nextTrack : .resumePlayback)
    }

    private var playbackCaption: String {
        if audioPlayer.isPlaying { return settings.text(.nowPlaying) }
        if audioPlayer.currentSong == nil || pausedTime >= audioPlayer.duration { return settings.text(.startListening) }
        let seconds = Int(max(pausedTime, 0))
        let time = String(format: "%d:%02d", seconds / 60, seconds % 60)
        return String(format: settings.text(.resumeFromTime), time)
    }
}

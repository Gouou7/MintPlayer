import SwiftUI

struct HomeWidgetArea: View {
    @EnvironmentObject private var settings: SettingsManager
    @AppStorage(AppConfiguration.userDefaultsKey("home.widgets.hidden")) private var hiddenWidgetStorage = ""

    let suggestedSong: Song?
    let onShowLyrics: () -> Void

    private var hiddenWidgets: Set<HomeWidgetKind> {
        Set(hiddenWidgetStorage.split(separator: ",").compactMap { HomeWidgetKind(rawValue: String($0)) })
    }

    private var visibleWidgets: [HomeWidgetKind] {
        HomeWidgetKind.allCases.filter { !hiddenWidgets.contains($0) }
    }

    var body: some View {
        HomeWidgetGridLayout(kinds: visibleWidgets) {
            ForEach(visibleWidgets) { kind in
                HomeWidgetContent(kind: kind, suggestedSong: suggestedSong, onShowLyrics: onShowLyrics)
                    .frame(width: kind.size.width, height: kind.size.height)
                    .contextMenu {
                        addMenu
                        Button { remove(kind) } label: {
                            Label(settings.text(.removeThisWidget), systemImage: "trash")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(settings.text(kind.titleKey))
                    .accessibilityAction(named: Text(settings.text(.removeThisWidget))) { remove(kind) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            addMenu
            Menu {
                ForEach(HomeWidgetKind.allCases) { kind in
                    if !hiddenWidgets.contains(kind) {
                        Button { remove(kind) } label: {
                            Label(settings.text(kind.titleKey), systemImage: kind.systemImage)
                        }
                    }
                }
            } label: {
                Label(settings.text(.removeWidget), systemImage: "minus.circle")
            }
            .disabled(visibleWidgets.isEmpty)
        }
        .overlay {
            if visibleWidgets.isEmpty {
                Text(settings.text(.addWidgetsHint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }

    private var addMenu: some View {
        Menu {
            ForEach(HomeWidgetKind.allCases) { kind in
                Button { add(kind) } label: {
                    Label(settings.text(kind.titleKey), systemImage: kind.systemImage)
                }
                .disabled(!hiddenWidgets.contains(kind))
            }
        } label: {
            Label(settings.text(.addWidget), systemImage: "plus.circle")
        }
    }

    private func add(_ kind: HomeWidgetKind) {
        var hidden = hiddenWidgets
        hidden.remove(kind)
        saveHiddenWidgets(hidden)
    }

    private func remove(_ kind: HomeWidgetKind) {
        var hidden = hiddenWidgets
        hidden.insert(kind)
        saveHiddenWidgets(hidden)
    }

    private func saveHiddenWidgets(_ hidden: Set<HomeWidgetKind>) {
        hiddenWidgetStorage = HomeWidgetKind.allCases.filter { hidden.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

private struct HomeWidgetGridLayout: Layout {
    let kinds: [HomeWidgetKind]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.width ?? HomeWidgetGrid.length(8)
        let width = proposedWidth.isFinite ? proposedWidth : HomeWidgetGrid.length(8)
        let placements = HomeWidgetGrid.placements(for: kinds, availableWidth: width)
        let rows = max(2, placements.map { $0.row + $0.kind.rowSpan }.max() ?? 0)
        return CGSize(width: width, height: HomeWidgetGrid.length(rows))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = HomeWidgetGrid.placements(for: kinds, availableWidth: bounds.width)
        for (placement, subview) in zip(placements, subviews) {
            subview.place(
                at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.kind.size)
            )
        }
    }
}

private enum HomeWidgetKind: String, CaseIterable, Identifiable, Hashable {
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

    var systemImage: String {
        switch self {
        case .favorites: return "heart.fill"
        case .shuffle: return "shuffle"
        case .resume: return "play.fill"
        case .lyrics: return "text.quote"
        }
    }
}

private struct HomeWidgetPlacement: Identifiable {
    let kind: HomeWidgetKind
    let column: Int
    let row: Int

    var id: HomeWidgetKind { kind }
    var origin: CGPoint { CGPoint(x: CGFloat(column) * HomeWidgetGrid.pitch, y: CGFloat(row) * HomeWidgetGrid.pitch) }
}

private enum HomeWidgetGrid {
    static let unit: CGFloat = 75
    static let spacing: CGFloat = 16
    static let pitch = unit + spacing

    static func placements(for kinds: [HomeWidgetKind], availableWidth: CGFloat) -> [HomeWidgetPlacement] {
        let fitsLyricsOnFirstRow = availableWidth >= length(8)
        return kinds.map { kind in
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
    }

    private var buttonTitle: String {
        settings.text(audioPlayer.isPlaying ? .nextTrack : .resumePlayback)
    }

    private var playbackCaption: String {
        if audioPlayer.isPlaying { return settings.text(.nowPlaying) }
        if audioPlayer.currentSong == nil || audioPlayer.currentTime >= audioPlayer.duration { return settings.text(.startListening) }
        let seconds = Int(max(audioPlayer.currentTime, 0))
        let time = String(format: "%d:%02d", seconds / 60, seconds % 60)
        return String(format: settings.text(.resumeFromTime), time)
    }
}

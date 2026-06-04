import SwiftUI
import AppKit
import QuartzCore
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

struct LyricsOverlayView: View {
    let song: Song
    let onClose: () -> Void

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var lyricsState: LyricsLoadState = .plainText([])
    @State private var previousButtonWiggleID = 0
    @State private var nextButtonWiggleID = 0

    private let artworkMaxSize: CGFloat = 400
    private let lyricsColumnWidth: CGFloat = 780

    var body: some View {
        GeometryReader { geometry in
            let layout = LyricsOverlayLayout(
                size: geometry.size,
                maximumArtworkSize: artworkMaxSize,
                maximumLyricsWidth: lyricsColumnWidth
            )

            ZStack {
                StaticLyricsBackground(coverPath: song.coverPath)

                Color.black.opacity(colorScheme == .dark ? 0.28 : 0.18)
                    .ignoresSafeArea()

                mainContent(layout: layout)
            }
        }
        .contentShape(Rectangle())
        .task(id: song.id) {
            lyricsState = LyricsService.loadLyrics(for: song)
        }
        .onExitCommand {
            onClose()
        }
    }

    private func mainContent(layout: LyricsOverlayLayout) -> some View {
        HStack(alignment: .top, spacing: layout.columnSpacing) {
            songInfo(
                maximumArtworkSize: layout.maximumArtworkSize,
                verticalSpacing: layout.leftPanelSpacing
            )
                .frame(
                    width: layout.leftPanelWidth,
                    height: layout.contentHeight,
                    alignment: layout.leftPanelAlignment
                )
                .offset(y: layout.leftPanelOffsetY)

            lyricsContent
                .frame(width: layout.lyricsWidth, height: layout.contentHeight, alignment: .top)
        }
        .frame(height: layout.contentHeight, alignment: .top)
        .padding(.horizontal, layout.horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func songInfo(maximumArtworkSize: CGFloat, verticalSpacing: CGFloat) -> some View {
        songInfoContent(artworkSize: maximumArtworkSize, verticalSpacing: verticalSpacing)
    }

    private func songInfoContent(artworkSize: CGFloat, verticalSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            ArtworkImage(
                path: song.coverPath,
                cornerRadius: 24,
                targetSize: CGSize(width: artworkSize, height: artworkSize),
                crossfadeChanges: true
            )
                .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 16)
            .frame(width: artworkSize, height: artworkSize)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(song.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)

                Text("\(song.artist) - \(song.album)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            progressInfo
                .fixedSize(horizontal: false, vertical: true)

            playbackControls
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var progressInfo: some View {
        VStack(spacing: 8) {
            FullscreenProgressSlider(
                value: Binding(
                    get: { min(audioPlayer.currentTime, max(audioPlayer.duration, 0)) },
                    set: { audioPlayer.seek(to: $0) }
                ),
                range: 0...max(audioPlayer.duration, 1)
            )
            .frame(height: 18)

            HStack {
                Text(formatTime(audioPlayer.currentTime))
                Spacer()
                Text(formatTime(audioPlayer.duration))
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var playbackControls: some View {
        HStack(spacing: 0) {
            Button {
                audioPlayer.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(PlaybackToggleButtonStyle(isActive: audioPlayer.isShuffleEnabled))
            .help(settings.text(.shuffle))

            Spacer(minLength: 24)

            Button {
                previousButtonWiggleID += 1
                audioPlayer.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .symbolEffect(.wiggle, value: previousButtonWiggleID)
            }
            .buttonStyle(MintPlainIconButtonStyle(hoverSize: CGSize(width: 46, height: 46)))
            .help(settings.text(.previous))

            Spacer(minLength: 24)

            Button(action: audioPlayer.togglePlayPause) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .frame(width: 43, height: 43)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.snappy(duration: 0.18), value: audioPlayer.isPlaying)
            }
            .buttonStyle(MintPlainIconButtonStyle(hoverSize: CGSize(width: 58, height: 58)))
            .help(audioPlayer.isPlaying ? settings.text(.pause) : settings.text(.play))

            Spacer(minLength: 24)

            Button {
                nextButtonWiggleID += 1
                audioPlayer.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .symbolEffect(.wiggle, value: nextButtonWiggleID)
            }
            .buttonStyle(MintPlainIconButtonStyle(hoverSize: CGSize(width: 46, height: 46)))
            .help(settings.text(.next))

            Spacer(minLength: 24)

            Button {
                audioPlayer.toggleRepeat()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(PlaybackToggleButtonStyle(isActive: audioPlayer.isRepeatEnabled))
            .help(settings.text(.repeatMode))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var lyricsContent: some View {
        switch lyricsState {
        case .synced(let lines):
            SyncedLyricsView(lines: lines)
                .environmentObject(audioPlayer)
        case .plainText(let lines):
            PlainLyricsView(lines: lines)
        case .missing:
            LyricsInfoStateView(
                title: settings.text(.noLyrics),
                detail: settings.text(.noLyricsFile)
            )
        case .failed(let message):
            LyricsInfoStateView(
                title: settings.text(.lyricsUnavailable),
                detail: message
            )
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(0, Int(time.rounded(.down)))
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}

private struct LyricsOverlayLayout {
    let horizontalInset: CGFloat
    let columnSpacing: CGFloat
    let contentHeight: CGFloat
    let leftPanelWidth: CGFloat
    let leftPanelAlignment: Alignment
    let leftPanelOffsetY: CGFloat
    let leftPanelSpacing: CGFloat
    let lyricsWidth: CGFloat
    let maximumArtworkSize: CGFloat

    private static let minimumArtworkSize: CGFloat = 160
    private static let minimumLyricsWidth: CGFloat = 340

    init(size: CGSize, maximumArtworkSize: CGFloat, maximumLyricsWidth: CGFloat) {
        horizontalInset = max(44, min(74, size.width * 0.055))
        columnSpacing = min(max(34, size.width * 0.04), 78)
        leftPanelSpacing = max(10, min(22, size.height * 0.025))

        contentHeight = max(0, size.height)
        let availableWidth = max(0, size.width - horizontalInset * 2 - columnSpacing)
        let leftWidthBudget = max(Self.minimumArtworkSize, availableWidth - Self.minimumLyricsWidth)
        let proportionalLeftWidth = max(Self.minimumArtworkSize, availableWidth * 0.39)
        leftPanelWidth = min(maximumArtworkSize, leftWidthBudget, proportionalLeftWidth)
        lyricsWidth = min(maximumLyricsWidth, max(Self.minimumLyricsWidth, availableWidth - leftPanelWidth))

        leftPanelAlignment = .center
        leftPanelOffsetY = min(max(8, size.height * 0.014), 12)
        self.maximumArtworkSize = min(maximumArtworkSize, leftPanelWidth)
    }
}

private struct StaticLyricsBackground: View {
    let coverPath: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: NSImage?
    @State private var displayedCacheKey: String?
    @State private var previousImage: NSImage?
    @State private var showsPreviousImage = false
    @State private var crossfadeGeneration = 0

    private let imageTransitionDuration: TimeInterval = 0.36

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .id(displayedCacheKey)
            }

            if let previousImage {
                Image(nsImage: previousImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(showsPreviousImage ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: imageTransitionDuration), value: showsPreviousImage)
        .overlay {
            Color.black.opacity(colorScheme == .dark ? 0.10 : 0.04)
        }
        .overlay {
            LyricsBackgroundEdgeFade(colorScheme: colorScheme)
        }
        .ignoresSafeArea()
        .task(id: cacheKey) {
            await loadImage(for: cacheKey)
        }
    }

    private var cacheKey: String {
        "\(coverPath ?? "empty")|\(colorScheme == .dark ? "dark" : "light")"
    }

    @MainActor
    private func loadImage(for requestedCacheKey: String) async {
        guard displayedCacheKey != requestedCacheKey else { return }

        let loadedImage = await LyricsBackdropCache.shared.image(for: coverPath, colorScheme: colorScheme)
        guard cacheKey == requestedCacheKey else { return }
        updateDisplayedImage(loadedImage, cacheKey: requestedCacheKey)
    }

    @MainActor
    private func updateDisplayedImage(_ nextImage: NSImage?, cacheKey nextCacheKey: String) {
        guard displayedCacheKey != nextCacheKey else { return }

        if let image {
            previousImage = image
            showsPreviousImage = true
        } else {
            previousImage = nil
            showsPreviousImage = false
        }

        image = nextImage
        displayedCacheKey = nextCacheKey

        guard previousImage != nil else { return }

        crossfadeGeneration += 1
        let generation = crossfadeGeneration

        withAnimation(.easeInOut(duration: imageTransitionDuration)) {
            showsPreviousImage = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(imageTransitionDuration * 1_000_000_000))
            guard crossfadeGeneration == generation else { return }
            previousImage = nil
        }
    }
}

private struct LyricsBackgroundEdgeFade: View {
    let colorScheme: ColorScheme

    private var edgeColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [edgeColor.opacity(colorScheme == .dark ? 0.18 : 0.10), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 74)

                Spacer(minLength: 0)

                LinearGradient(
                    colors: [.clear, edgeColor.opacity(colorScheme == .dark ? 0.16 : 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 74)
            }
        }
        .allowsHitTesting(false)
    }
}

private final class LyricsBackdropCache {
    static let shared = LyricsBackdropCache()

    private let cache = NSCache<NSString, NSImage>()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let pointSize = CGSize(width: 900, height: 900)
    private let scale: CGFloat = 2

    private init() {
        cache.countLimit = 12
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for coverPath: String?, colorScheme: ColorScheme) async -> NSImage {
        let key = cacheKey(path: coverPath, colorScheme: colorScheme) as NSString
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        return await Task.detached(priority: .utility) {
            let image = self.renderBackdrop(path: coverPath, colorScheme: colorScheme)
            self.cache.setObject(image, forKey: key, cost: self.cost)
            return image
        }.value
    }

    private var pixelSize: CGSize {
        CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
    }

    private var cost: Int {
        Int(pixelSize.width * pixelSize.height * 4)
    }

    private func cacheKey(path: String?, colorScheme: ColorScheme) -> String {
        "\(path ?? "empty")|\(colorScheme == .dark ? "dark" : "light")"
    }

    private func renderBackdrop(path: String?, colorScheme: ColorScheme) -> NSImage {
        let rect = CGRect(origin: .zero, size: pixelSize)
        let baseImage = sourceImage(path: path, extent: rect) ?? fallbackImage(extent: rect, colorScheme: colorScheme)
        let blurredImage = baseImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 86])
            .cropped(to: rect)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.22,
                kCIInputContrastKey: 1.08,
                kCIInputBrightnessKey: colorScheme == .dark ? -0.06 : 0.02
            ])

        let overlayColor = colorScheme == .dark
            ? CIColor(red: 0.05, green: 0.045, blue: 0.04, alpha: 0.42)
            : CIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 0.28)
        let overlay = CIImage(color: overlayColor).cropped(to: rect)
        let finalImage = overlay.composited(over: blurredImage)

        guard let cgImage = context.createCGImage(finalImage, from: rect) else {
            return NSImage(size: pointSize)
        }

        return NSImage(cgImage: cgImage, size: pointSize)
    }

    private func sourceImage(path: String?, extent: CGRect) -> CIImage? {
        guard let path, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(extent.width, extent.height))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return CIImage(cgImage: cgImage).scaledAndCropped(to: extent)
    }

    private func fallbackImage(extent: CGRect, colorScheme: ColorScheme) -> CIImage {
        let start = CGPoint(x: extent.minX, y: extent.maxY)
        let end = CGPoint(x: extent.maxX, y: extent.minY)
        let color0 = colorScheme == .dark
            ? CIColor(red: 0.08, green: 0.12, blue: 0.10, alpha: 1)
            : CIColor(red: 0.83, green: 0.96, blue: 0.88, alpha: 1)
        let color1 = colorScheme == .dark
            ? CIColor(red: 0.18, green: 0.11, blue: 0.07, alpha: 1)
            : CIColor(red: 0.96, green: 0.90, blue: 0.82, alpha: 1)

        let gradient = CIFilter.linearGradient()
        gradient.point0 = start
        gradient.point1 = end
        gradient.color0 = color0
        gradient.color1 = color1
        return (gradient.outputImage ?? CIImage(color: color0)).cropped(to: extent)
    }
}

private extension CIImage {
    func scaledAndCropped(to targetExtent: CGRect) -> CIImage {
        let sourceExtent = extent
        guard sourceExtent.width > 0, sourceExtent.height > 0 else {
            return cropped(to: targetExtent)
        }

        let scale = max(targetExtent.width / sourceExtent.width, targetExtent.height / sourceExtent.height)
        let scaledImage = transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = targetExtent.midX - scaledImage.extent.midX
        let dy = targetExtent.midY - scaledImage.extent.midY

        return scaledImage
            .transformed(by: CGAffineTransform(translationX: dx, y: dy))
            .cropped(to: targetExtent)
    }
}

private struct FullscreenProgressSlider: View {
    @Binding var value: TimeInterval
    let range: ClosedRange<TimeInterval>

    @State private var isHovering = false
    @State private var isDragging = false

    private let trackHeight: CGFloat = 7
    private let knobDiameter: CGFloat = 15
    private let hitHeight: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progress = normalizedProgress
            let progressWidth = width * progress
            let showsKnob = isHovering || isDragging

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white.opacity(0.74))
                    .frame(width: max(progressWidth, progress > 0 ? trackHeight : 0), height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
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
                        isDragging = true
                        updateValue(locationX: gestureValue.location.x, width: width)
                    }
                    .onEnded { gestureValue in
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

private struct PlaybackToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    private let hoverSize: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, isActive: isActive, hoverSize: hoverSize)
    }

    private struct ButtonBody: View {
        let configuration: Configuration
        let isActive: Bool
        let hoverSize: CGFloat
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isActive ? MintTheme.accent : Color.secondary)
                .frame(width: hoverSize, height: hoverSize)
                .opacity(configuration.isPressed ? 0.78 : 1)
                .contentShape(Circle())
                .background {
                    if configuration.isPressed {
                        Circle()
                            .fill(MintTheme.pressedFill)
                    } else if isHovered {
                        Circle()
                            .fill(MintTheme.hoverFill)
                    }
                }
                .onHover { isHovered = $0 }
        }
    }
}

private struct SyncedLyricsView: View {
    let lines: [LyricLine]

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var settings: SettingsManager
    @State private var lyricsScrollView: NSScrollView?
    @State private var lineMidYByID: [LyricLine.ID: CGFloat] = [:]

    private let lineSpacing: CGFloat = 18
    private let lyricFocusAnchorY: CGFloat = 0.18
    private let compactFocusSpacerHeight: CGFloat = 132

    private var activeLineIndex: Int? {
        guard !lines.isEmpty else { return nil }

        let currentTime = audioPlayer.currentTime
        var activeIndex: Int?

        for index in lines.indices {
            let line = lines[index]
            if line.time <= currentTime {
                activeIndex = index
            } else {
                break
            }
        }

        return activeIndex
    }

    private var highlightedLineID: LyricLine.ID? {
        guard let activeLineIndex, lines.indices.contains(activeLineIndex) else { return nil }
        return lines[activeLineIndex].id
    }

    private var activeLineLyricWindow: TimeInterval {
        guard let activeLineIndex else { return 0.32 }

        let activeLine = lines[activeLineIndex]
        let nextLineTime = lines.indices.contains(activeLineIndex + 1)
            ? lines[activeLineIndex + 1].time
            : activeLine.time + 1.6
        return max(nextLineTime - activeLine.time, 0)
    }

    private var scrollTransitionDuration: TimeInterval {
        min(logisticTransitionDuration(for: activeLineLyricWindow) * 0.519, max(0.17, activeLineLyricWindow * 0.338))
    }

    private var highlightTransitionDuration: TimeInterval {
        min(logisticTransitionDuration(for: activeLineLyricWindow) * 0.58, max(0.22, activeLineLyricWindow * 0.42))
    }

    private func logisticTransitionDuration(for lyricWindow: TimeInterval) -> TimeInterval {
        let minimumDuration: TimeInterval = 0.68
        let maximumDuration: TimeInterval = 1.92
        let midpoint: TimeInterval = 2.0
        let steepness: TimeInterval = 2.2
        let normalized = 1 / (1 + exp(-steepness * (lyricWindow - midpoint)))

        return minimumDuration + (maximumDuration - minimumDuration) * normalized
    }

    private func activeLineTransitionAnimation(duration: TimeInterval) -> Animation {
        .timingCurve(0.45, 0.0, 0.20, 1.0, duration: duration)
    }

    private func distanceFromActiveLine(for index: Int) -> Int {
        guard let activeLineIndex else { return 4 }
        return abs(index - activeLineIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            let focusSpacerHeight = focusSpacerHeight(for: geometry.size.height)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: lineSpacing) {
                    Color.clear
                        .frame(height: focusSpacerHeight)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        LyricLineRow(
                            line: line,
                            distanceFromActiveLine: distanceFromActiveLine(for: index),
                            isBlurEnabled: settings.lyricsBlurEnabled,
                            transitionAnimation: activeLineTransitionAnimation(duration: highlightTransitionDuration)
                        )
                        .id(line.id)
                        .background {
                            LyricsLinePositionReader(lineID: line.id)
                        }
                        .onTapGesture {
                            audioPlayer.seek(to: line.time)
                        }
                    }

                    Color.clear
                        .frame(height: focusSpacerHeight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .coordinateSpace(name: LyricsScrollCoordinateSpace.name)
                .background {
                    LyricsScrollViewResolver { scrollView in
                        lyricsScrollView = scrollView
                    }
                }
            }
            .onPreferenceChange(LyricsLinePositionPreferenceKey.self) { positions in
                lineMidYByID = positions
                scrollToHighlightedLine(viewportHeight: geometry.size.height, animated: false)
            }
            .onAppear {
                scrollToHighlightedLine(viewportHeight: geometry.size.height, animated: false)
            }
            .onChange(of: lyricsScrollView != nil) { _, hasScrollView in
                guard hasScrollView else { return }
                scrollToHighlightedLine(viewportHeight: geometry.size.height, animated: false)
            }
            .onChange(of: highlightedLineID) { _, _ in
                scrollToHighlightedLine(viewportHeight: geometry.size.height, animated: true)
            }
        }
    }

    private func scrollToHighlightedLine(viewportHeight: CGFloat, animated: Bool) {
        guard let highlightedLineID,
              let lineMidY = lineMidYByID[highlightedLineID],
              let scrollView = lyricsScrollView
        else { return }

        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let focusY = viewportHeight * lyricFocusAnchorY
        let maximumOffsetY = max(documentHeight - visibleHeight, 0)
        let targetOffsetY = min(max(lineMidY - focusY, 0), maximumOffsetY)
        let targetOrigin = CGPoint(x: scrollView.contentView.bounds.origin.x, y: targetOffsetY)

        guard animated else {
            scrollView.contentView.scroll(to: targetOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = scrollTransitionDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.45, 0.0, 0.20, 1.0)
            scrollView.contentView.animator().setBoundsOrigin(targetOrigin)
        } completionHandler: {
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func focusSpacerHeight(for viewportHeight: CGFloat) -> CGFloat {
        let centeredSpacerHeight = viewportHeight * lyricFocusAnchorY
        let compactHeightLimit = min(compactFocusSpacerHeight, viewportHeight * 0.28)
        let compactRatio = min(max((viewportHeight - 600) / 180, 0), 1)

        return compactHeightLimit + (centeredSpacerHeight - compactHeightLimit) * compactRatio
    }
}

private struct LyricLineRow: View {
    let line: LyricLine
    let distanceFromActiveLine: Int
    let isBlurEnabled: Bool
    let transitionAnimation: Animation

    var body: some View {
        Text(line.text)
            .font(.system(size: 24, weight: .semibold))
            .lineSpacing(8)
            .foregroundStyle(distanceFromActiveLine == 0 ? .primary : .secondary)
            .opacity(opacity)
            .blur(radius: blurRadius)
            .contentShape(Rectangle())
            .animation(transitionAnimation, value: distanceFromActiveLine)
    }

    private var blurRadius: CGFloat {
        guard isBlurEnabled else { return 0 }

        switch distanceFromActiveLine {
        case 0:
            return 0
        case 1:
            return 0.25
        case 2:
            return 0.48
        case 3:
            return 0.70
        case 4:
            return 0.92
        case 5:
            return 1.14
        case 6:
            return 1.36
        case 7:
            return 1.58
        case 8:
            return 1.80
        case 9:
            return 2.02
        case 10:
            return 2.24
        case 11:
            return 2.42
        default:
            return 2.6
        }
    }

    private var opacity: Double {
        switch distanceFromActiveLine {
        case 0:
            return 0.98
        case 1:
            return 0.62
        case 2:
            return 0.58
        case 3:
            return 0.54
        case 4:
            return 0.50
        case 5:
            return 0.46
        case 6:
            return 0.42
        case 7:
            return 0.38
        case 8:
            return 0.35
        case 9:
            return 0.32
        case 10:
            return 0.29
        case 11:
            return 0.27
        default:
            return 0.25
        }
    }
}

private enum LyricsScrollCoordinateSpace {
    static let name = "LyricsScrollCoordinateSpace"
}

private struct LyricsLinePositionPreferenceKey: PreferenceKey {
    static var defaultValue: [LyricLine.ID: CGFloat] = [:]

    static func reduce(value: inout [LyricLine.ID: CGFloat], nextValue: () -> [LyricLine.ID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct LyricsLinePositionReader: View {
    let lineID: LyricLine.ID

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: LyricsLinePositionPreferenceKey.self,
                value: [lineID: proxy.frame(in: .named(LyricsScrollCoordinateSpace.name)).midY]
            )
        }
    }
}

private struct LyricsScrollViewResolver: NSViewRepresentable {
    let onResolve: (NSScrollView?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(view.enclosingScrollView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.enclosingScrollView)
        }
    }
}

private struct PlainLyricsView: View {
    let lines: [String]
    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        if lines.isEmpty {
            LyricsInfoStateView(
                title: settings.text(.noLyrics),
                detail: settings.text(.emptyLyrics)
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 24, weight: .semibold))
                            .lineSpacing(8)
                            .foregroundStyle(.secondary)
                            .opacity(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 48)
            }
        }
    }
}

private struct LyricsInfoStateView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct LyricsWindowView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let currentSong = audioPlayer.currentSong {
                LyricsOverlayView(song: currentSong) {
                    dismissWindow(id: "lyrics")
                }
                .environmentObject(audioPlayer)
                .environmentObject(settings)
                .preferredColorScheme(settings.preferredColorScheme)
            } else {
                EmptyLyricsWindowView {
                    dismissWindow(id: "lyrics")
                }
                .environmentObject(settings)
            }
        }
        .frame(minWidth: 980, minHeight: 600)
        .background {
            LyricsWindowConfigurator()
                .frame(width: 0, height: 0)
            PlaybackSpaceKeyHandler()
                .frame(width: 0, height: 0)
        }
    }
}

private struct LyricsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> HostView {
        HostView()
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.configureSoon()
    }

    final class HostView: NSView {
        private weak var configuredWindow: NSWindow?
        private var frameObservers: [NSObjectProtocol] = []

        deinit {
            removeFrameObservers()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureSoon()
        }

        func configureSoon() {
            DispatchQueue.main.async { [weak self] in
                self?.configureWindow()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.configureWindow()
            }
        }

        private func configureWindow() {
            guard let window else { return }

            if configuredWindow !== window {
                removeFrameObservers()
                configuredWindow = window
            }

            window.identifier = NSUserInterfaceItemIdentifier("mintPlayer.lyricsWindow")
            window.styleMask.insert(.resizable)
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.collectionBehavior.remove(.fullScreenAuxiliary)
            window.minSize = NSSize(width: 980, height: 600)
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.standardWindowButton(.zoomButton)?.isEnabled = true

            observeFrameChanges(for: window)
        }

        private func observeFrameChanges(for window: NSWindow) {
            guard frameObservers.isEmpty else { return }

            let center = NotificationCenter.default
            let notifications: [NSNotification.Name] = [
                NSWindow.didMoveNotification,
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.willCloseNotification
            ]

            frameObservers = notifications.map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    guard let self, let window, self.configuredWindow === window else { return }
                    self.saveFrame(for: window)
                }
            }
        }

        private func saveFrame(for window: NSWindow) {
            WindowFramePersistence.saveFrame(window.frame, for: .lyrics)
        }

        private func removeFrameObservers() {
            frameObservers.forEach(NotificationCenter.default.removeObserver)
            frameObservers = []
        }
    }
}

enum WindowFramePersistence {
    enum Window: String {
        case lyrics
        case settings
    }

    static func savedFrame(for window: Window) -> CGRect? {
        guard let frameString = UserDefaults.standard.string(forKey: key(for: window)) else { return nil }

        let frame = NSRectFromString(frameString)
        return frame.isEmpty ? nil : frame
    }

    static func saveFrame(_ frame: CGRect, for window: Window) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key(for: window))
    }

    static func constrainedFrame(_ frame: CGRect, minimumSize: CGSize, displayFrame: CGRect) -> CGRect {
        var constrainedFrame = frame
        constrainedFrame.size.width = min(max(constrainedFrame.width, minimumSize.width), displayFrame.width)
        constrainedFrame.size.height = min(max(constrainedFrame.height, minimumSize.height), displayFrame.height)

        if !displayFrame.intersects(constrainedFrame) {
            constrainedFrame.origin.x = displayFrame.midX - constrainedFrame.width / 2
            constrainedFrame.origin.y = displayFrame.midY - constrainedFrame.height / 2
        }

        return constrainedFrame
    }

    private static func key(for window: Window) -> String {
        AppConfiguration.userDefaultsKey("window.\(window.rawValue).frame")
    }
}

private struct EmptyLyricsWindowView: View {
    @EnvironmentObject private var settings: SettingsManager
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(settings.text(.noSongPlaying))
                    .font(.title3.weight(.bold))

                Button(settings.text(.close), action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(MintTheme.accent)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                onClose()
            }
        }
    }
}

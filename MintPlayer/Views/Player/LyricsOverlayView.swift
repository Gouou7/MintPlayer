import SwiftUI

struct LyricsOverlayView: View {
    let song: Song
    @Binding var isPresented: Bool
    
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var lyricsState: LyricsLoadState = .plainText([])
    @State private var isBackgroundRotating = false
    @State private var isContentPresented = false
    
    private let lyricsColumnWidth: CGFloat = 520
    private let artworkMaxSize: CGFloat = 360
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DynamicLyricsBackground(
                    coverPath: song.coverPath,
                    isRotating: isBackgroundRotating
                )
                
                Color.black.opacity(colorScheme == .dark ? 0.28 : 0.18)
                    .ignoresSafeArea()
                
                lyricsContentGroup(in: geometry)
            }
            .ignoresSafeArea()
        }
        .task(id: song.id) {
            lyricsState = LyricsService.loadLyrics(for: song)
        }
        .onAppear {
            isBackgroundRotating = true
            isContentPresented = false
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.36)) {
                    isContentPresented = true
                }
            }
        }
        .onExitCommand {
            isPresented = false
        }
    }
    
    private func lyricsContentGroup(in geometry: GeometryProxy) -> some View {
        ZStack {
            mainContent(in: geometry)
            
            closeButton
                .padding(.top, 28)
                .padding(.trailing, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .opacity(isContentPresented ? 1 : 0)
        .offset(y: isContentPresented ? 0 : 42)
    }
    
    private func mainContent(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 72) {
            songInfo
                .frame(width: min(artworkMaxSize, max(260, geometry.size.width * 0.26)))
            
            lyricsContent
                .frame(width: min(lyricsColumnWidth, max(360, geometry.size.width * 0.42)))
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, max(48, geometry.size.width * 0.08))
        .padding(.vertical, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var songInfo: some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                ArtworkImage(path: song.coverPath, cornerRadius: 24, targetSize: CGSize(width: 520, height: 520))
                    .blur(radius: 18)
                    .opacity(0.34)
                    .scaleEffect(1.05)
                
                ArtworkImage(path: song.coverPath, cornerRadius: 24, targetSize: CGSize(width: 520, height: 520))
                    .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 22)
            }
            .aspectRatio(1, contentMode: .fit)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(song.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(song.artist)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(song.album)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            progressInfo
        }
    }
    
    private var progressInfo: some View {
        VStack(spacing: 8) {
            ProgressView(value: min(audioPlayer.currentTime, max(audioPlayer.duration, 0)), total: max(audioPlayer.duration, 1))
                .tint(MintTheme.accent)
            
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                Spacer()
                Text(formatTime(audioPlayer.duration))
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
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
                title: "No Lyrics",
                detail: "未找到与当前歌曲同目录同名的 .lrc 文件"
            )
        case .failed(let message):
            LyricsInfoStateView(
                title: "Lyrics Unavailable",
                detail: message
            )
        }
    }
    
    private var closeButton: some View {
        Button {
            isPresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(MintPlainIconButtonStyle())
        .help("Close Lyrics")
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = max(0, Int(time.rounded(.down)))
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}

struct LyricsOverlayChromeCoverView: View {
    let song: Song
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isBackgroundRotating = false
    
    var body: some View {
        ZStack {
            DynamicLyricsBackground(
                coverPath: song.coverPath,
                isRotating: isBackgroundRotating
            )
            
            Color.black.opacity(colorScheme == .dark ? 0.28 : 0.18)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            isBackgroundRotating = true
        }
    }
}

private struct DynamicLyricsBackground: View {
    let coverPath: String?
    let isRotating: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                
                if coverPath != nil {
                    backgroundLayer(in: geometry, alignment: .topTrailing, direction: 1)
                        .blendMode(.luminosity)
                    
                    backgroundLayer(in: geometry, alignment: .bottomLeading, direction: -1)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private func backgroundLayer(in geometry: GeometryProxy, alignment: Alignment, direction: Double) -> some View {
        let size = max(geometry.size.width, geometry.size.height) * 1.45
        
        return ArtworkImage(
            path: coverPath,
            cornerRadius: 0,
            targetSize: CGSize(width: size, height: size)
        )
        .frame(width: size, height: size)
        .scaleEffect(1.08)
        .blur(radius: 54)
        .saturation(1.22)
        .contrast(1.12)
        .brightness(-0.06)
        .opacity(0.62)
        .rotationEffect(.degrees(isRotating ? 360 * direction : 0))
        .animation(.linear(duration: 150).repeatForever(autoreverses: false), value: isRotating)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

private struct SyncedLyricsView: View {
    let lines: [LyricLine]
    
    @EnvironmentObject private var audioPlayer: AudioPlayer
    
    private var highlightedLineID: LyricLine.ID? {
        guard !lines.isEmpty else { return nil }
        
        let currentTime = audioPlayer.currentTime
        var activeLine = lines[0]
        
        for line in lines {
            if line.time <= currentTime {
                activeLine = line
            } else {
                break
            }
        }
        
        return activeLine.id
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Color.clear
                            .frame(height: geometry.size.height * 0.42)
                        
                        ForEach(lines) { line in
                            LyricLineRow(
                                line: line,
                                isHighlighted: line.id == highlightedLineID
                            )
                            .id(line.id)
                            .onTapGesture {
                                audioPlayer.seek(to: line.time)
                            }
                        }
                        
                        Color.clear
                            .frame(height: geometry.size.height * 0.42)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onAppear {
                    scrollToHighlightedLine(with: proxy)
                }
                .onChange(of: highlightedLineID) { _, _ in
                    scrollToHighlightedLine(with: proxy)
                }
            }
        }
    }
    
    private func scrollToHighlightedLine(with proxy: ScrollViewProxy) {
        guard let highlightedLineID else { return }
        withAnimation(.easeInOut(duration: 0.38)) {
            proxy.scrollTo(highlightedLineID, anchor: .center)
        }
    }
}

private struct LyricLineRow: View {
    let line: LyricLine
    let isHighlighted: Bool
    
    var body: some View {
        Text(line.text)
            .font(.system(size: isHighlighted ? 32 : 27, weight: isHighlighted ? .bold : .semibold))
            .lineSpacing(8)
            .foregroundStyle(isHighlighted ? .primary : .secondary)
            .opacity(isHighlighted ? 0.96 : 0.42)
            .scaleEffect(isHighlighted ? 1 : 0.96, anchor: .leading)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.22), value: isHighlighted)
    }
}

private struct PlainLyricsView: View {
    let lines: [String]
    
    var body: some View {
        if lines.isEmpty {
            LyricsInfoStateView(
                title: "No Lyrics",
                detail: "歌词文件里没有可显示的文本"
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 27, weight: .semibold))
                            .lineSpacing(8)
                            .foregroundStyle(.secondary)
                            .opacity(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 96)
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

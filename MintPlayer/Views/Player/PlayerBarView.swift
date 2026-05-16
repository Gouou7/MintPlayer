import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
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
            PlayerIconButton(systemName: "shuffle", isActive: audioPlayer.isShuffleEnabled) {
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
            PlayerIconButton(systemName: "repeat", isActive: audioPlayer.isRepeatEnabled) {
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
                    Text("Not Playing")
                        .font(.callout.weight(.bold))
                        .lineLimit(1)
                    Text("Choose a song to start listening")
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
            Button(action: { isQueuePresented.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(MintPlainIconButtonStyle())
            .help("Up Next")
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
            .help("Volume")
            .popover(isPresented: $isVolumePresented, arrowEdge: .bottom) {
                volumeControl
                    .frame(width: 220)
                    .padding(14)
            }
        }
    }
    
    private var progressBar: some View {
        Slider(
            value: Binding(
                get: { min(audioPlayer.currentTime, max(audioPlayer.duration, 0)) },
                set: { audioPlayer.seek(to: $0) }
            ),
            in: 0...max(audioPlayer.duration, 1)
        )
        .controlSize(.mini)
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
    
    private func artwork(for song: Song) -> some View {
        Button(action: onArtworkClick) {
            ArtworkImage(path: song.coverPath, cornerRadius: 8)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(MintContentButtonStyle(cornerRadius: 8))
        .help("Show Lyrics")
    }
    
    private func togglePlay() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.resume()
        }
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(width: 22, height: 24)
        }
        .buttonStyle(MintPlainIconButtonStyle(isActive: isActive))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1)
    }
}

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.headline)
            
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OperationErrorView: View {
    @EnvironmentObject private var settings: SettingsManager
    let message: String
    let retry: () -> Void
    let dismiss: () -> Void
    @State private var showsDetails = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.callout).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(settings.text(.showDetails)) { showsDetails = true }
                .popover(isPresented: $showsDetails) {
                    ScrollView { Text(message).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                        .frame(width: 420, height: 240)
                }
            Button(settings.text(.retry), action: retry)
            Button(action: dismiss) { Label(settings.text(.close), systemImage: "xmark") }
                .labelStyle(.iconOnly)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct PlaybackErrorView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer

    var body: some View {
        if let message = audioPlayer.playbackError {
            OperationErrorView(message: message, retry: audioPlayer.retryPlayback) {
                audioPlayer.playbackError = nil
            }
        }
    }
}

struct LibraryActivityView: View {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        VStack(spacing: 8) {
            if musicLibrary.isScanning {
                HStack {
                    ProgressView().controlSize(.small)
                    if musicLibrary.pendingImports > 0 {
                        Text(String(format: settings.text(.importingFiles), musicLibrary.importedFileCount))
                    } else {
                        Text(String(format: settings.text(.scanningFiles), processedCount))
                    }
                    Spacer()
                }
                .font(.callout)
            }
            if let message = musicLibrary.lastScanError {
                OperationErrorView(message: message, retry: musicLibrary.retryFailedOperations) {
                    musicLibrary.lastScanError = nil
                }
            }
            PlaybackErrorView()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, musicLibrary.isScanning || musicLibrary.lastScanError != nil ? 8 : 0)
    }

    private var processedCount: Int {
        musicLibrary.librarySources.filter(\.isScanning).reduce(0) { $0 + (musicLibrary.scanProgress[$1.id] ?? 0) }
    }
}

import SwiftUI

struct ListPlaybackControls: View {
    @EnvironmentObject private var settings: SettingsManager

    let songs: [Song]
    let playAction: () -> Void
    let shuffleAction: () -> Void

    static let buttonWidth: CGFloat = 99
    static let buttonHeight: CGFloat = 30

    private var isDisabled: Bool {
        songs.isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: playAction) {
                Label(settings.text(.play), systemImage: "play.fill")
                    .frame(width: Self.buttonWidth, height: Self.buttonHeight)
            }
            .buttonStyle(.borderedProminent)

            Button(action: shuffleAction) {
                Label(settings.text(.shuffle), systemImage: "shuffle")
                    .frame(width: Self.buttonWidth, height: Self.buttonHeight)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .disabled(isDisabled)
    }
}

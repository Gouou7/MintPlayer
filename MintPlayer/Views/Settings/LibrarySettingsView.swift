import SwiftUI
import AppKit

struct LibrarySettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var musicLibrary: MusicLibrary

    @State private var selectedTheme = ThemeMode.dark
    @State private var selectedLanguage = AppLanguage.system
    @State private var lyricsBlurEnabled = true
    @State private var showFolderPicker = false
    @State private var newLibraryPath = ""
    @State private var folderPendingDeletion: MusicLibrarySource?

    var body: some View {
        Form {
            appearanceSettings
            playbackSettings
            librarySettings
            aboutSettings
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .frame(minWidth: 620, minHeight: 640)
        .background {
            SettingsWindowConfigurator()
                .frame(width: 0, height: 0)
        }
        .onAppear {
            selectedTheme = settings.theme
            selectedLanguage = settings.language
            lyricsBlurEnabled = settings.lyricsBlurEnabled
        }
        .onChange(of: selectedTheme) { _, newTheme in
            settings.updateTheme(newTheme)
        }
        .onChange(of: selectedLanguage) { _, newLanguage in
            settings.updateLanguage(newLanguage)
        }
        .onChange(of: lyricsBlurEnabled) { _, isEnabled in
            settings.updateLyricsBlurEnabled(isEnabled)
        }
        .confirmationDialog(
            settings.text(.deleteFolderQuestion),
            isPresented: folderDeletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { source in
            Button(settings.text(.deleteFolder), role: .destructive) {
                musicLibrary.removeLibrarySource(id: source.id)
                folderPendingDeletion = nil
            }
            Button(settings.text(.cancel), role: .cancel) {
                folderPendingDeletion = nil
            }
        } message: { source in
            Text(String(format: settings.text(.deleteFolderMessage), source.name))
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                newLibraryPath = url.path
                addLibrary(url: url)
            case .failure(let error):
                print("Error picking folder: \(error)")
            }
        }
    }

    private var appearanceSettings: some View {
        Section(settings.text(.appearance)) {
            SettingsPickerRow(
                title: settings.text(.interfaceTheme),
                description: settings.text(.themeDescription),
                selection: $selectedTheme
            ) {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    Text(themeTitle(theme))
                        .tag(theme)
                }
            }

            SettingsPickerRow(
                title: settings.text(.language),
                description: settings.text(.languageDescription),
                selection: $selectedLanguage
            ) {
                ForEach([AppLanguage.system, .chinese, .english], id: \.self) { language in
                    Text(languageTitle(language))
                        .tag(language)
                }
            }
        }
    }

    private var playbackSettings: some View {
        Section(settings.text(.playbackPage)) {
            SettingsToggleRow(
                title: settings.text(.lyricsBlurEffect),
                description: settings.text(.lyricsBlurDescription),
                isOn: $lyricsBlurEnabled
            )
        }
    }

    private var librarySettings: some View {
        Section(settings.text(.library)) {
            Button {
                showFolderPicker = true
            } label: {
                Label(settings.text(.addMusicLibrary), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            if musicLibrary.librarySources.isEmpty {
                ContentUnavailableView(
                    settings.text(.noMusicLibraries),
                    systemImage: "folder",
                    description: Text(settings.text(.addFolderDescription))
                )
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ForEach(musicLibrary.librarySources) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        librarySourceRow(source)

                        let blockedSongs = musicLibrary.blockedSongs(in: source)
                        if !blockedSongs.isEmpty {
                            blockedSongsList(blockedSongs)
                                .padding(.leading, 40)
                        }
                    }
                }
            }

            Button {
                musicLibrary.rescanAllLibraries()
            } label: {
                Label(settings.text(.rescanAll), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(musicLibrary.librarySources.isEmpty)
        }
    }

    private func librarySourceRow(_ source: MusicLibrarySource) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(source.name)
                            .font(.body.weight(.medium))

                        Text("(\(source.path))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)

                    if source.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let lastScanned = source.lastScanned {
                    Text("\(settings.text(.lastScanned)): \(formattedDate(lastScanned))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                musicLibrary.scanLibrarySource(source)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(source.isScanning)
            .help(settings.text(.rescan))

            Button(role: .destructive) {
                folderPendingDeletion = source
            } label: {
                Image(systemName: "trash.fill")
            }
            .buttonStyle(.borderless)
            .help(settings.text(.remove))
        }
        .padding(.vertical, 4)
    }

    private func blockedSongsList(_ songs: [BlockedSong]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(settings.text(.blockedSongs)):", systemImage: "eye.slash")
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            ForEach(songs) { song in
                blockedSongRow(song)
            }
        }
    }

    private func blockedSongRow(_ song: BlockedSong) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text("\(song.artist) - \(song.album)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                musicLibrary.unblockSong(song)
            } label: {
                Label(settings.text(.unblock), systemImage: "eye")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(settings.text(.unblockSong))
        }
        .padding(.vertical, 3)
    }

    private var aboutSettings: some View {
        Section(settings.text(.about)) {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppConfiguration.displayName)
                        .font(.headline)
                    Text(settings.versionText)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var folderDeletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { folderPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    folderPendingDeletion = nil
                }
            }
        )
    }

    private func addLibrary(url: URL) {
        let alert = NSAlert()
        alert.messageText = settings.text(.addMusicLibrary)
        alert.informativeText = settings.text(.enterLibraryName)
        alert.addButton(withTitle: settings.text(.add))
        alert.addButton(withTitle: settings.text(.cancel))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = url.lastPathComponent
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        musicLibrary.addLibrarySource(name: name, path: newLibraryPath)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func themeTitle(_ theme: ThemeMode) -> String {
        switch theme {
        case .system:
            return settings.text(.systemTheme)
        case .light:
            return settings.text(.lightTheme)
        case .dark:
            return settings.text(.darkTheme)
        }
    }

    private func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            return settings.text(.systemLanguage)
        case .english:
            return "English"
        case .chinese:
            return settings.effectiveLanguage == .chinese ? "中文简体" : "Simplified Chinese"
        }
    }
}

private struct SettingsPickerRow<SelectionValue: Hashable, Content: View>: View {
    let title: String
    let description: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            settingsLabel

            Spacer(minLength: 16)

            Picker("", selection: $selection) {
                content()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var settingsLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .fixedSize()
        }
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
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
        }

        private func configureWindow() {
            guard let window else { return }

            if configuredWindow !== window {
                removeFrameObservers()
                configuredWindow = window
            }

            window.styleMask.insert(.resizable)
            window.minSize = NSSize(width: 620, height: 640)
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
            WindowFramePersistence.saveFrame(window.frame, for: .settings)
        }

        private func removeFrameObservers() {
            frameObservers.forEach(NotificationCenter.default.removeObserver)
            frameObservers = []
        }
    }
}

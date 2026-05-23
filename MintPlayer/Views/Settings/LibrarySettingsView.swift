import SwiftUI
import AppKit

struct LibrarySettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var musicLibrary: MusicLibrary

    @State private var selectedTheme = ThemeMode.dark
    @State private var selectedLanguage = AppLanguage.system
    @State private var showFolderPicker = false
    @State private var newLibraryPath = ""

    var body: some View {
        Form {
            appearanceSettings
            libraryControls
            foldersSettings
            aboutSettings
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 640)
        .scenePadding()
        .onAppear {
            selectedTheme = settings.theme
            selectedLanguage = settings.language
        }
        .onChange(of: selectedTheme) { _, newTheme in
            settings.updateTheme(newTheme)
        }
        .onChange(of: selectedLanguage) { _, newLanguage in
            settings.updateLanguage(newLanguage)
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
            Picker(settings.text(.theme), selection: $selectedTheme) {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    Text(themeTitle(theme))
                        .tag(theme)
                }
            }
            .pickerStyle(.menu)

            Text(settings.text(.themeDescription))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(settings.text(.language), selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(languageTitle(language))
                        .tag(language)
                }
            }
            .pickerStyle(.menu)

            Text(settings.text(.languageDescription))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var libraryControls: some View {
        Section {
            HStack {
                Button {
                    showFolderPicker = true
                } label: {
                    Label(settings.text(.addMusicLibrary), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    musicLibrary.rescanAllLibraries()
                } label: {
                    Label(settings.text(.rescanAll), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(musicLibrary.librarySources.isEmpty)
            }
        } header: {
            Text(settings.text(.musicLibrary))
        } footer: {
            Text(settings.text(.libraryDescription))
        }
    }

    private var foldersSettings: some View {
        Section(settings.text(.folders)) {
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
                    Text(source.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if source.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(source.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

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
                musicLibrary.removeLibrarySource(id: source.id)
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
            Label(settings.text(.blockedSongs), systemImage: "eye.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
                    .font(.callout.weight(.medium))
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
            return "简体中文"
        }
    }
}

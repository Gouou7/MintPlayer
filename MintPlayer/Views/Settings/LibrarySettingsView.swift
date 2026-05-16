import SwiftUI
import AppKit

struct LibrarySettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var musicLibrary: MusicLibrary
    
    @State private var selectedTheme = ThemeMode.dark
    @State private var showFolderPicker = false
    @State private var newLibraryPath = ""
    
    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            librarySettings
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
            
            aboutSettings
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 540, height: 420)
        .scenePadding()
        .onAppear {
            selectedTheme = settings.theme
        }
        .onChange(of: selectedTheme) { _, newTheme in
            settings.updateTheme(newTheme)
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
    
    private var generalSettings: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(ThemeMode.allCases, id: \.self) { theme in
                        Text(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                
                Text("Choose the appearance used by Mint Player windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    private var librarySettings: some View {
        Form {
            Section {
                HStack {
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Add Music Library", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        musicLibrary.rescanAllLibraries()
                    } label: {
                        Label("Rescan All", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(musicLibrary.librarySources.isEmpty)
                }
            } header: {
                Text("Music Library")
            } footer: {
                Text("Add folders that contain local music files. Rescanning updates metadata and artwork for existing library folders.")
            }
            
            Section("Folders") {
                if musicLibrary.librarySources.isEmpty {
                    ContentUnavailableView(
                        "No music libraries",
                        systemImage: "folder",
                        description: Text("Add a folder to start building your local library.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    ForEach(musicLibrary.librarySources) { source in
                        librarySourceRow(source)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
                    Text("Last scanned: \(formattedDate(lastScanned))")
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
            .help("Rescan")
            
            Button(role: .destructive) {
                musicLibrary.removeLibrarySource(id: source.id)
            } label: {
                Image(systemName: "trash.fill")
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 4)
    }
    
    private var aboutSettings: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(MintTheme.accent)
                        .frame(width: 52)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mint Player")
                            .font(.headline)
                        Text("Version 0.2.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
    
    private func addLibrary(url: URL) {
        let alert = NSAlert()
        alert.messageText = "Add Music Library"
        alert.informativeText = "Enter a name for this music library"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
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
}

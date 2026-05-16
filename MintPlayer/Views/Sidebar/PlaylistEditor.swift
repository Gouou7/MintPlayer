import SwiftUI

struct PlaylistEditorDraft: Identifiable {
    let id = UUID()
    let playlistId: UUID?
    let title: String
    let confirmTitle: String
    var name: String
    var description: String
    
    static func create(defaultName: String = "New Playlist") -> PlaylistEditorDraft {
        PlaylistEditorDraft(
            playlistId: nil,
            title: "New Playlist",
            confirmTitle: "Create",
            name: defaultName,
            description: ""
        )
    }
    
    static func edit(_ playlist: Playlist) -> PlaylistEditorDraft {
        PlaylistEditorDraft(
            playlistId: playlist.id,
            title: "Edit Playlist",
            confirmTitle: "Save",
            name: playlist.name,
            description: playlist.description
        )
    }
}

struct PlaylistEditorSheet: View {
    let draft: PlaylistEditorDraft
    let onCancel: () -> Void
    let onSave: (String, String) -> Void
    
    @State private var name: String
    @State private var description: String
    
    init(
        draft: PlaylistEditorDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String) -> Void
    ) {
        self.draft = draft
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: draft.name)
        _description = State(initialValue: draft.description)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(draft.title)
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                TextField("Playlist Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $description)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                    
                    if description.isEmpty {
                        Text("Add notes, mood, context, or anything useful for this playlist.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 210)
                .background(Color(.textBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
            }
            
            HStack(spacing: 12) {
                Spacer()
                
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button(draft.confirmTitle) {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 560, height: 440)
    }
}

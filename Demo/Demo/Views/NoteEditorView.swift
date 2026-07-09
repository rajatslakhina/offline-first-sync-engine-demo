import SwiftUI
import SyncEngineCoreData

/// Create/edit sheet. Saving is instant from the user's perspective — the
/// sheet dismisses the moment the local write completes, never waiting on
/// the network. That immediacy *is* the optimistic-UI behavior the source
/// article calls "the breakthrough": the network is not treated as
/// confirmation.
struct NoteEditorView: View {
    let existingNote: Note?
    let onSave: (String, String) async -> Void

    @State private var title: String
    @State private var noteBody: String
    @Environment(\.dismiss) private var dismiss

    init(existingNote: Note?, onSave: @escaping (String, String) async -> Void) {
        self.existingNote = existingNote
        self.onSave = onSave
        _title = State(initialValue: existingNote?.title ?? "")
        _noteBody = State(initialValue: existingNote?.body ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Note title", text: $title)
                }
                Section("Body") {
                    TextEditor(text: $noteBody)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let savedTitle = title
                        let savedBody = noteBody
                        dismiss()
                        Task { await onSave(savedTitle, savedBody) }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

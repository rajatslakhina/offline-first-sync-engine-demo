import SwiftUI
import SyncEngineCoreData

struct NotesListView: View {
    @State var viewModel: NotesViewModel

    @State private var showingEditor = false
    @State private var editingNote: Note?
    @State private var showingNetworkSimulator = false
    @State private var showingConflicts = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.notes) { note in
                    Button {
                        editingNote = note
                        showingEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(note.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                SyncStatusBadge(status: note.syncStatus)
                            }
                            if !note.body.isEmpty {
                                Text(note.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let toDelete = offsets.map { viewModel.notes[$0] }
                    Task {
                        for note in toDelete {
                            await viewModel.deleteNote(note)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "note.text",
                        description: Text("Add one — it saves instantly, synced or not.")
                    )
                }
            }
            .navigationTitle("Offline-First Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingNetworkSimulator = true
                    } label: {
                        Label("Network", systemImage: "wifi.exclamationmark")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !viewModel.conflictsAwaitingDecision.isEmpty {
                        Button {
                            showingConflicts = true
                        } label: {
                            Label("\(viewModel.conflictsAwaitingDecision.count)", systemImage: "exclamationmark.triangle.fill")
                        }
                        .tint(.red)
                    }
                    Button {
                        Task { await viewModel.syncNow() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        editingNote = nil
                        showingEditor = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .status) {
                    SyncStatusBanner(status: viewModel.syncStatus)
                }
            }
            .sheet(isPresented: $showingEditor) {
                NoteEditorView(existingNote: editingNote) { title, body in
                    if let editingNote {
                        await viewModel.updateNote(editingNote, title: title, body: body)
                    } else {
                        await viewModel.addNote(title: title, body: body)
                    }
                }
            }
            .sheet(isPresented: $showingNetworkSimulator) {
                NetworkSimulatorView(configuration: $viewModel.networkConfiguration) {
                    await viewModel.applyNetworkConfiguration()
                }
            }
            .sheet(isPresented: $showingConflicts) {
                ConflictResolutionView(conflicts: viewModel.conflictsAwaitingDecision) { conflict, keepLocal in
                    await viewModel.resolveConflict(conflict, keepLocal: keepLocal)
                }
            }
            .task {
                await viewModel.start()
            }
        }
    }
}

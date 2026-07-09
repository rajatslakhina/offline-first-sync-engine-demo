import SwiftUI

/// The UI half of the article's "User Intervention" conflict strategy.
/// Architectural purity means nothing if the person actually holding the
/// phone doesn't trust the app — this screen is where that trust gets
/// earned or lost, so every row explicitly names what's at stake (a delete,
/// an edit) rather than showing a bare "conflict" label.
struct ConflictResolutionView: View {
    let conflicts: [ConflictPresentation]
    let onResolve: (ConflictPresentation, Bool) async -> Void

    var body: some View {
        NavigationStack {
            List(conflicts) { conflict in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: conflict.operation.kind == .delete ? "trash.fill" : "pencil")
                            .foregroundStyle(.red)
                        Text(conflict.noteTitle)
                            .font(.headline)
                    }
                    Text(explanation(for: conflict))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Keep Mine") {
                            Task { await onResolve(conflict, true) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Keep Server's") {
                            Task { await onResolve(conflict, false) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Needs Your Decision")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if conflicts.isEmpty {
                    ContentUnavailableView(
                        "All Clear",
                        systemImage: "checkmark.circle",
                        description: Text("No conflicts are waiting on you right now.")
                    )
                }
            }
        }
    }

    private func explanation(for conflict: ConflictPresentation) -> String {
        switch conflict.operation.kind {
        case .delete:
            "This note was deleted on this device but changed on another. Deletes are never resolved automatically."
        case .update, .create:
            "This note was edited on this device while a different device changed it too. Pick which version wins."
        }
    }
}

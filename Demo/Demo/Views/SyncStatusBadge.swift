import SwiftUI
import SyncEngineCoreData

/// Small, reusable per-row status pill. Kept as its own view rather than
/// inline `switch` sprinkled across the list row, so the color/label
/// mapping lives in exactly one place.
struct SyncStatusBadge: View {
    let status: SyncStatusLabel

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .pending: "Pending"
        case .synced: "Synced"
        case .conflict: "Conflict"
        case .failed: "Failed"
        }
    }

    private var color: Color {
        switch status {
        case .pending: .orange
        case .synced: .green
        case .conflict: .red
        case .failed: .red
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        SyncStatusBadge(status: .pending)
        SyncStatusBadge(status: .synced)
        SyncStatusBadge(status: .conflict)
        SyncStatusBadge(status: .failed)
    }
    .padding()
}

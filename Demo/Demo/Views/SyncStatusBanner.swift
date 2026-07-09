import SwiftUI
import SyncEngineCore

/// The one place in the app that surfaces engine-wide sync state. Deliberately
/// terse — a banner that over-explains itself trains users to ignore it.
struct SyncStatusBanner: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(text)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(tint)
    }

    private var icon: some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "circle.dashed")
            case .syncing:
                ProgressView().scaleEffect(0.7)
            case .synced:
                Image(systemName: "checkmark.circle.fill")
            case .needsAttention:
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .frame(width: 16, height: 16)
    }

    private var text: String {
        switch status {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing…"
        case let .synced(at):
            "Synced \(at.formatted(date: .omitted, time: .shortened))"
        case let .needsAttention(failed, conflicts, awaitingDecision):
            var parts: [String] = []
            if failed > 0 { parts.append("\(failed) failed") }
            if conflicts > 0 { parts.append("\(conflicts) conflicts") }
            if awaitingDecision > 0 { parts.append("\(awaitingDecision) need you") }
            return parts.joined(separator: ", ")
        }
    }

    private var tint: Color {
        switch status {
        case .idle: .secondary
        case .syncing: .blue
        case .synced: .green
        case .needsAttention: .red
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        SyncStatusBanner(status: .idle)
        SyncStatusBanner(status: .syncing)
        SyncStatusBanner(status: .synced(at: .now))
        SyncStatusBanner(status: .needsAttention(failed: 1, conflicts: 2, awaitingDecision: 1))
    }
    .padding()
}

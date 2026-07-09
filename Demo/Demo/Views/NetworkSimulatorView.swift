import SwiftUI
import SyncEngineCore

/// This sheet exists for exactly one reason: the interesting behavior in an
/// offline-first system (retries, backoff, conflicts, the user-decision
/// path) doesn't show up on a happy-path network. Real Wi-Fi drops don't
/// arrive on cue, so the demo needs a way to manufacture flakiness on demand.
struct NetworkSimulatorView: View {
    @Binding var configuration: MockRemoteAPIClient.Configuration
    let onChange: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Offline", isOn: $configuration.isOffline)
                } footer: {
                    Text("Every upload fails immediately — the classic subway/elevator scenario from the article's opening.")
                }

                Section("Failure rate") {
                    Slider(value: $configuration.failureRate, in: 0...1, step: 0.05) {
                        Text("Failure rate")
                    }
                    Text("\(Int(configuration.failureRate * 100))% of uploads time out")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Conflict rate") {
                    Slider(value: $configuration.conflictRate, in: 0...1, step: 0.05) {
                        Text("Conflict rate")
                    }
                    Text("\(Int(configuration.conflictRate * 100))% of uploads collide with a remote change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Network Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: configuration.isOffline) { _, _ in Task { await onChange() } }
            .onChange(of: configuration.failureRate) { _, _ in Task { await onChange() } }
            .onChange(of: configuration.conflictRate) { _, _ in Task { await onChange() } }
        }
    }
}

import Foundation
import Observation
import SyncEngineCore
import SyncEngineCoreData

/// A pending operation shown in the conflict-resolution sheet, paired with
/// enough context for the user to actually make a decision instead of
/// picking blind. The article's article's rule ("irreversible actions →
/// user confirmation") only works if the UI shows *what* is being confirmed.
struct ConflictPresentation: Identifiable {
    let operation: SyncOperation
    let noteTitle: String
    var id: SyncOperation.ID { operation.id }
}

/// The one and only thing SwiftUI talks to. Matches the article's rule
/// exactly: "SwiftUI never talks to the network," "the UI only reads from
/// Core Data." Every mutation here goes through `NoteRepository` (which
/// writes Core Data first, optimistically) and `SyncCoordinator` (which
/// owns if/when that write ever touches the network).
@MainActor
@Observable
final class NotesViewModel {
    private(set) var notes: [Note] = []
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var conflictsAwaitingDecision: [ConflictPresentation] = []
    var networkConfiguration: MockRemoteAPIClient.Configuration

    private let repository: NoteRepository
    private let coordinator: SyncCoordinator
    private let pendingStore: any PendingOperationStore
    private let remoteAPI: MockRemoteAPIClient
    private var statusTask: Task<Void, Never>?

    init(
        repository: NoteRepository,
        coordinator: SyncCoordinator,
        pendingStore: any PendingOperationStore,
        remoteAPI: MockRemoteAPIClient
    ) {
        self.repository = repository
        self.coordinator = coordinator
        self.pendingStore = pendingStore
        self.remoteAPI = remoteAPI
        self.networkConfiguration = .init()
    }

    func start() async {
        await refreshNotes()
        await coordinator.start()
        statusTask = Task { [weak self] in
            guard let self else { return }
            for await status in await self.coordinator.statusUpdates() {
                self.syncStatus = status
                await self.refreshNotes()
                await self.refreshConflicts()
            }
        }
    }

    func stop() {
        statusTask?.cancel()
        Task { await coordinator.stop() }
    }

    func refreshNotes() async {
        notes = await repository.fetchAll()
    }

    func refreshConflicts() async {
        let pending = await pendingStore.fetchAwaitingUserDecision()
        conflictsAwaitingDecision = pending.map { operation in
            let title = notes.first(where: { $0.id.uuidString == operation.entityID })?.title ?? "(deleted note)"
            return ConflictPresentation(operation: operation, noteTitle: title)
        }
    }

    // MARK: - Note mutations (optimistic — always local-first)

    func addNote(title: String, body: String) async {
        _ = await repository.create(title: title, body: body)
        await refreshNotes()
    }

    func updateNote(_ note: Note, title: String, body: String) async {
        var updated = note
        updated.title = title
        updated.body = body
        await repository.update(updated)
        await refreshNotes()
    }

    func deleteNote(_ note: Note) async {
        await repository.delete(note.id)
        await refreshNotes()
    }

    // MARK: - Sync controls

    func syncNow() async {
        await coordinator.syncNow()
    }

    func applyNetworkConfiguration() async {
        await remoteAPI.updateConfiguration(networkConfiguration)
    }

    func toggleOffline() async {
        networkConfiguration.isOffline.toggle()
        await applyNetworkConfiguration()
    }

    /// The "keep mine" / "keep server's" resolution the article's
    /// user-intervention strategy exists to collect. Resolving here means
    /// the *user*, not a heuristic, decided — which is the whole point.
    func resolveConflict(_ presentation: ConflictPresentation, keepLocal: Bool) async {
        if keepLocal {
            // Re-save the operation with retry bookkeeping reset so the
            // next sync pass treats it as a fresh upload attempt.
            var retried = presentation.operation
            retried.retryCount = 0
            retried.lastError = nil
            retried.nextRetryAt = nil
            await pendingStore.save(retried)
        } else {
            await pendingStore.remove(presentation.operation.id)
        }
        await refreshConflicts()
        await coordinator.syncNow()
    }
}

import SwiftUI
import SyncEngineCore
import SyncEngineCoreData

@main
struct DemoApp: App {
    /// Assembled once, at launch — this is the app's one and only
    /// composition root. Nothing downstream constructs its own
    /// `CoreDataStack`, `SyncManager`, or `MockRemoteAPIClient`; everything
    /// gets handed the instances built here. That's what makes the
    /// dependency graph in the article's diagram ("SwiftUI View → ViewModel
    /// → Repository → Local Store ↔ Sync Engine ↔ Remote API") a real,
    /// enforced shape in code instead of just a diagram.
    private let stack: CoreDataStack
    private let viewModel: NotesViewModel

    init() {
        let stack = CoreDataStack()
        self.stack = stack

        let deviceID = DemoApp.currentDeviceID()
        let backgroundContext = stack.newBackgroundContext()

        let pendingStore = CoreDataPendingOperationStore(context: backgroundContext)
        let repository = NoteRepository(context: backgroundContext, pendingStore: pendingStore, deviceID: deviceID)
        let remoteAPI = MockRemoteAPIClient(remoteDeviceID: "server")

        // Non-destructive fields (title/body edits) get last-write-wins with
        // device-precedence tie-breaking; deletes are routed to user
        // intervention unconditionally by HybridConflictResolver itself —
        // see the source article's "How We Classified Conflicts" section.
        let conflictResolver = HybridConflictResolver(precedenceDeviceID: deviceID) { _ in .nonDestructive }

        let syncManager = SyncManager(
            store: pendingStore,
            api: remoteAPI,
            conflictResolver: conflictResolver
        )
        let changeObserver = CoreDataChangeObserver(context: backgroundContext)
        let coordinator = SyncCoordinator(syncManager: syncManager, changeObserver: changeObserver)

        viewModel = NotesViewModel(
            repository: repository,
            coordinator: coordinator,
            pendingStore: pendingStore,
            remoteAPI: remoteAPI
        )
    }

    var body: some Scene {
        WindowGroup {
            NotesListView(viewModel: viewModel)
        }
    }

    /// A stable per-install identifier standing in for "this device," used
    /// as the tiebreaker in `DeviceTimestampPrecedenceResolver`. Persisted
    /// in `UserDefaults` rather than regenerated per launch, so multi-device
    /// conflict demos (running two Simulators) are actually reproducible.
    private static func currentDeviceID() -> String {
        let key = "com.offlinefirstsyncengine.demo.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = "device-\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

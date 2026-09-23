import AppKit
import Observation

/// App-scoped ownership of open workspaces, unbound defaults and coordinated termination.
@MainActor
@Observable
final class WorkspaceWindows {
    let preferences: AppPreferences
    let emptyWorkspace: WorkspaceModel
    private(set) var workspaces: [WorkspaceModel] = []
    private(set) var activeWorkspace: WorkspaceModel?
    private(set) var isFlushingAll = false
    @ObservationIgnored private var didRestoreInitialVault = false
    @ObservationIgnored private var started = Set<ObjectIdentifier>()
    @ObservationIgnored var dockBadgeUpdate: (@MainActor (String?) -> Void)?

    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
        emptyWorkspace = WorkspaceModel(preferences: preferences)
    }

    var settingsWorkspace: WorkspaceModel {
        activeWorkspace ?? emptyWorkspace
    }

    var hasPendingChanges: Bool {
        workspaces.contains { $0.isLoading || $0.hasPendingDocumentChanges }
    }

    func register(_ model: WorkspaceModel) {
        guard !workspaces.contains(where: { $0 === model }) else { return }
        workspaces.append(model)
    }

    func activate(_ model: WorkspaceModel) {
        register(model)
        activeWorkspace = model
    }

    func start(_ model: WorkspaceModel) async {
        guard !Task.isCancelled, started.insert(ObjectIdentifier(model)).inserted else { return }
        register(model)
        let restoresRecentVault = !didRestoreInitialVault
        didRestoreInitialVault = true
        if restoresRecentVault, model.snapshot == nil {
            await model.restoreVault()
        }
    }

    func remove(_ model: WorkspaceModel) {
        workspaces.removeAll { $0 === model }
        started.remove(ObjectIdentifier(model))
        if activeWorkspace === model {
            activeWorkspace = workspaces.last
        }
    }

    func flushAll() async -> Bool {
        guard !isFlushingAll else { return false }
        isFlushingAll = true
        defer { isFlushingAll = false }
        var saved = true
        for model in workspaces {
            let flushed = model.isLoading ? false : await model.flushTaskChanges()
            if !flushed {
                model.errorMessage = "Finish capture and resolve pending changes before quitting."
                saved = false
            }
        }
        return saved && !hasPendingChanges
    }
}

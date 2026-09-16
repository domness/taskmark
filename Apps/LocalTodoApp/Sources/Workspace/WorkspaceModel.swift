import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Observation

@MainActor
@Observable
final class WorkspaceModel {
    var snapshot: VaultSnapshot?
    var route: WorkspaceRoute = .today {
        didSet {
            if route != .search {
                searchText = ""
            }
            if route != oldValue {
                selectedTaskPath = nil
                prepareProjectDraft()
            }
        }
    }

    var selectedTaskPath: VaultPath?
    var searchText = ""
    var isInspectorPresented = true
    var isCommandPalettePresented = false
    var isQuickCapturePresented = false
    var quickCaptureTitle = ""
    var newEntityKind: NewEntityKind?
    var errorMessage: String?
    var isLoading = false
    var isHistoryBusy = false
    var titleEditRequest = 0
    var titleEditingPath: VaultPath?
    var searchFocusRequest = 0
    var taskListDisplayOptionsByRoute: [String: TaskListDisplayOptions]

    @ObservationIgnored var store: VaultStore?
    @ObservationIgnored weak var undoManager: UndoManager?
    @ObservationIgnored var pendingMutationPaths = Set<VaultPath>()
    @ObservationIgnored var completedTaskStatuses = [VaultPath: TaskStatus]()
    @ObservationIgnored var autosaveTasks = [VaultPath: Task<Void, Never>]()
    @ObservationIgnored var modelEpoch: UInt64 = 0
    @ObservationIgnored private var scopedVault: SecurityScopedVault?
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    @ObservationIgnored private let bookmarks: VaultBookmarkStore
    @ObservationIgnored private(set) var vaultSession = UUID()
    @ObservationIgnored private var openRequest = UUID()
    @ObservationIgnored private var refreshRequest = UUID()
    @ObservationIgnored var taskDrafts = [VaultPath: TaskDraft]()
    @ObservationIgnored var projectDrafts = [VaultPath: ProjectDraft]()
    @ObservationIgnored let taskListDisplayPreferences: TaskListDisplayPreferencesStore

    init(
        bookmarks: VaultBookmarkStore = VaultBookmarkStore(),
        taskListDisplayPreferences: TaskListDisplayPreferencesStore = TaskListDisplayPreferencesStore()
    ) {
        self.bookmarks = bookmarks
        self.taskListDisplayPreferences = taskListDisplayPreferences
        taskListDisplayOptionsByRoute = taskListDisplayPreferences.load()
    }

    deinit {
        refreshLoop?.cancel()
        for task in autosaveTasks.values {
            task.cancel()
        }
    }

    var vaultName: String? {
        scopedVault?.url.lastPathComponent
    }

    var rootURL: URL? {
        scopedVault?.url
    }

    func restoreVault() async {
        do {
            if let url = try bookmarks.restore() {
                if try await openVault(url) {
                    try bookmarks.save(url)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func chooseVault() async {
        guard canChangeVault(), let url = await VaultPicker.chooseExistingVault() else {
            return
        }
        do {
            if try await openVault(url) {
                try bookmarks.save(url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createVault() async {
        guard canChangeVault(), let url = await VaultPicker.chooseNewVaultDirectory() else {
            return
        }
        await createVault(at: url)
    }

    func createVault(at url: URL) async {
        guard !isLoading, pendingMutationPaths.isEmpty, !isHistoryBusy else { return }
        let access = SecurityScopedVault(url: url)
        defer { _ = access }
        do {
            try VaultInitializer.initialize(at: url)
            if try await openVault(url) {
                try bookmarks.save(url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let store else { return }
        let session = vaultSession
        let epoch = modelEpoch
        let request = UUID()
        refreshRequest = request
        do {
            let nextSnapshot = try await store.snapshot()
            guard session == vaultSession, epoch == modelEpoch, request == refreshRequest else { return }
            if let snapshot, containsExternalChanges(from: snapshot, to: nextSnapshot) {
                clearHistory()
            }
            snapshot = nextSnapshot
            await reconcileDrafts(with: nextSnapshot)
            reconcileProjectDrafts(nextSnapshot)
            if let selectedTaskPath, nextSnapshot.tasks[selectedTaskPath] == nil {
                if taskDrafts[selectedTaskPath]?.isDirty != true {
                    self.selectedTaskPath = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func canChangeVault() -> Bool {
        guard !isLoading else { return false }
        guard pendingMutationPaths.isEmpty, !isHistoryBusy else {
            errorMessage = "Wait for the current change to finish before switching vaults."
            return false
        }
        guard !hasDirtyDrafts else {
            errorMessage = "Wait for document changes to save or fix invalid fields before switching vaults."
            return false
        }
        guard !isQuickCapturePresented else {
            errorMessage = "Finish or cancel quick capture before switching vaults."
            return false
        }
        return true
    }

    private func openVault(_ url: URL) async throws -> Bool {
        let request = UUID()
        openRequest = request
        isLoading = true
        defer { isLoading = false }
        let access = SecurityScopedVault(url: url)
        let store = VaultStore(root: url)
        let snapshot = try await store.snapshot()
        guard request == openRequest else { return false }
        guard !hasDirtyDrafts else {
            throw VaultSwitchError.unsavedTaskChanges
        }
        guard pendingMutationPaths.isEmpty, !isHistoryBusy else {
            throw VaultSwitchError.activeMutation
        }
        guard !isQuickCapturePresented else {
            throw VaultSwitchError.activeQuickCapture
        }
        refreshLoop?.cancel()
        for task in autosaveTasks.values {
            task.cancel()
        }
        clearHistory()
        modelEpoch += 1
        vaultSession = UUID()
        scopedVault = access
        self.store = store
        self.snapshot = snapshot
        taskDrafts.removeAll()
        projectDrafts.removeAll()
        autosaveTasks.removeAll()
        pendingMutationPaths.removeAll()
        completedTaskStatuses.removeAll()
        route = .today
        selectedTaskPath = nil
        startRefreshLoop()
        return true
    }

    private func startRefreshLoop() {
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }
}

enum NewEntityKind: String, Identifiable {
    case project
    case area

    var id: String {
        rawValue
    }
}

private enum VaultSwitchError: LocalizedError {
    case unsavedTaskChanges
    case activeQuickCapture
    case activeMutation

    var errorDescription: String? {
        switch self {
        case .unsavedTaskChanges: "Wait for task changes to save or fix invalid fields before switching vaults."
        case .activeQuickCapture: "Finish or cancel quick capture before switching vaults."
        case .activeMutation: "Wait for the current change to finish before switching vaults."
        }
    }
}

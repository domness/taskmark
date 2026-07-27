import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Observation

@MainActor
@Observable
final class WorkspaceModel {
    var snapshot: VaultSnapshot?
    var route: WorkspaceRoute = .today
    var selectedTaskPath: VaultPath?
    var searchText = ""
    var isInspectorPresented = true
    var isCommandPalettePresented = false
    var isQuickCapturePresented = false
    var newEntityKind: NewEntityKind?
    var errorMessage: String?
    var isLoading = false

    @ObservationIgnored var store: VaultStore?
    @ObservationIgnored private var scopedVault: SecurityScopedVault?
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    @ObservationIgnored private let bookmarks = VaultBookmarkStore()
    @ObservationIgnored private(set) var vaultSession = UUID()
    @ObservationIgnored private var openRequest = UUID()
    @ObservationIgnored private var taskDrafts = [VaultPath: TaskDraft]()

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
        guard !isLoading else { return }
        guard !taskDrafts.values.contains(where: \.isDirty) else {
            errorMessage = "Save or revert task changes before switching vaults."
            return
        }
        guard !isQuickCapturePresented else {
            errorMessage = "Finish or cancel quick capture before switching vaults."
            return
        }
        guard let url = await VaultPicker.chooseDirectory() else {
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

    func refresh() async {
        guard let store else { return }
        let session = vaultSession
        do {
            let nextSnapshot = try await store.snapshot()
            guard session == vaultSession else { return }
            snapshot = nextSnapshot
            reconcileDrafts(with: nextSnapshot)
            if let selectedTaskPath, nextSnapshot.tasks[selectedTaskPath] == nil {
                if taskDrafts[selectedTaskPath]?.isDirty != true {
                    self.selectedTaskPath = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginQuickCapture() {
        guard snapshot != nil else { return }
        isQuickCapturePresented = true
    }

    func selectTask(_ path: VaultPath?) {
        selectedTaskPath = path
        guard let path, let record = snapshot?.tasks[path] else { return }
        if taskDrafts[path] == nil {
            taskDrafts[path] = TaskDraft(record: record, vaultSession: vaultSession)
        }
    }

    var selectedTaskDraft: TaskDraft? {
        guard let selectedTaskPath else { return nil }
        return taskDrafts[selectedTaskPath]
    }

    func discardChanges(for path: VaultPath) {
        if let record = snapshot?.tasks[path] {
            taskDrafts[path]?.reset(to: record)
        } else {
            taskDrafts.removeValue(forKey: path)
            if selectedTaskPath == path {
                selectedTaskPath = nil
            }
        }
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
        guard !taskDrafts.values.contains(where: \.isDirty) else {
            throw VaultSwitchError.unsavedTaskChanges
        }
        guard !isQuickCapturePresented else {
            throw VaultSwitchError.activeQuickCapture
        }
        refreshLoop?.cancel()
        vaultSession = UUID()
        scopedVault = access
        self.store = store
        self.snapshot = snapshot
        taskDrafts.removeAll()
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

    private func reconcileDrafts(with snapshot: VaultSnapshot) {
        for (path, draft) in taskDrafts {
            guard let record = snapshot.tasks[path] else { continue }
            if !draft.isDirty, draft.revision != record.revision {
                draft.reset(to: record)
            }
        }
        guard let selectedTaskPath else { return }
        if taskDrafts[selectedTaskPath] == nil, let record = snapshot.tasks[selectedTaskPath] {
            taskDrafts[selectedTaskPath] = TaskDraft(record: record, vaultSession: vaultSession)
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

    var errorDescription: String? {
        switch self {
        case .unsavedTaskChanges: "Save or discard task changes before switching vaults."
        case .activeQuickCapture: "Finish or cancel quick capture before switching vaults."
        }
    }
}

import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func deleteCollection(at path: VaultPath) async {
        if snapshot?.projects[path] != nil {
            await removeOrganization(.project(path), actionName: "Delete Project")
        } else if snapshot?.areas[path] != nil {
            await removeOrganization(.area(path), actionName: "Delete Area")
        }
    }

    func deleteTag(_ tag: String) async {
        await removeOrganization(.tag(tag), actionName: "Delete Tag")
    }

    private func removeOrganization(_ removal: OrganizationRemoval, actionName: String) async {
        guard !isHistoryBusy, !isRemovingOrganization else { return }
        let session = vaultSession
        guard await flushTaskChanges(), session == vaultSession else {
            errorMessage = "Save or resolve pending changes before removing organization metadata."
            return
        }
        guard canPerformHistory, !isRemovingOrganization, let store else { return }
        let revision: FileRevision? = switch removal {
        case let .project(path), let .area(path): entityRecord(at: path)?.revision
        case .tag: nil
        }
        beginOrganizationChange()
        defer { endOrganizationChange() }
        do {
            let changes = try await store.planOrganizationRemoval(removal, expectedRevision: revision)
            let result = await store.applyOrganizationChanges(changes, now: clock())
            guard session == vaultSession else { return }
            acceptOrganizationChanges(result)
            await refresh(allowingOrganizationChange: true)
            guard session == vaultSession else { return }
            registerOrganizationRemovalHistory(result.undo, actionName: actionName)
            if result.errorMessage == nil {
                leaveRemovedOrganization(removal)
            }
        } catch {
            errorMessage = error.localizedDescription
            await refresh(allowingOrganizationChange: true)
        }
    }

    private func leaveRemovedOrganization(_ removal: OrganizationRemoval) {
        switch (removal, route) {
        case let (.project(path), .project(selected)) where path == selected: route = .inbox
        case let (.area(path), .area(selected)) where path == selected: route = .inbox
        case let (.tag(tag), .tag(selected)) where tag == selected: route = .inbox
        default: break
        }
    }

    private func registerOrganizationRemovalHistory(_ changes: OrganizationChangeSet, actionName: String) {
        guard !changes.isEmpty else { return }
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.performOrganizationRemovalHistory(changes, actionName: actionName) }
        }
        undoManager?.setActionName(actionName)
    }

    private func performOrganizationRemovalHistory(_ changes: OrganizationChangeSet, actionName: String) {
        guard canPerformHistory, !isRemovingOrganization, let store else { return }
        // UndoManager requires the reciprocal action synchronously inside its callback.
        // A failed sequence replaces this optimistic entry with recovery for only completed steps.
        registerOrganizationRemovalHistory(changes.inverse, actionName: actionName)
        beginOrganizationChange()
        isHistoryBusy = true
        let session = vaultSession
        Task {
            defer { endOrganizationChange(); isHistoryBusy = false }
            let result = await store.applyOrganizationChanges(changes, now: clock())
            guard session == vaultSession else { return }
            acceptOrganizationChanges(result)
            if result.errorMessage != nil {
                clearHistory()
            }
            await refresh(allowingOrganizationChange: true)
            guard session == vaultSession else { return }
            if result.errorMessage != nil {
                registerOrganizationRemovalHistory(result.undo, actionName: actionName)
            }
        }
    }

    private func beginOrganizationChange() {
        isRemovingOrganization = true
        filterState.isSaving = true
        filterState.readGeneration += 1
        modelEpoch += 1
    }

    private func endOrganizationChange() {
        isRemovingOrganization = false
        filterState.isSaving = false
    }

    private func acceptOrganizationChanges(_ result: OrganizationChangeResult) {
        for record in result.records {
            merge(record)
        }
        for path in result.deletedPaths {
            removeEntity(at: path)
        }
        if let filters = result.filters {
            filterState.record = filters
            // Keep the working editor's base revision: its unsaved criteria may still contain the removed value.
        }
        errorMessage = result.errorMessage
    }
}

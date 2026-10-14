import Foundation
import LocalTodoMarkdown

extension WorkspaceModel {
    func refresh(allowingOrganizationChange: Bool = false) async {
        guard !isRemovingOrganization || allowingOrganizationChange else { return }
        let session = vaultSession
        await refreshQueue.run { [weak self] in
            guard let self, vaultSession == session else { return }
            await performRefresh(allowingOrganizationChange: allowingOrganizationChange)
        }
    }

    private func performRefresh(allowingOrganizationChange: Bool) async {
        guard let store, !isRemovingOrganization || allowingOrganizationChange else { return }
        let session = vaultSession
        let epoch = modelEpoch
        let request = UUID()
        refreshRequest = request
        do {
            let nextSnapshot = try await store.snapshot()
            guard session == vaultSession, epoch == modelEpoch, request == refreshRequest,
                  !isRemovingOrganization || allowingOrganizationChange else { return }
            if let snapshot, containsExternalChanges(from: snapshot, to: nextSnapshot) {
                clearHistory()
            }
            if snapshot?.hasSameContent(as: nextSnapshot) != true {
                snapshot = nextSnapshot
            }
            updatePresentationDay()
            await reconcileRefresh(nextSnapshot, session: session, epoch: epoch)
        } catch {
            guard session == vaultSession, epoch == modelEpoch else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func reconcileRefresh(_ nextSnapshot: VaultSnapshot, session: UUID, epoch: UInt64) async {
        await reconcileDrafts(with: nextSnapshot)
        guard session == vaultSession, epoch == modelEpoch else { return }
        reconcileProjectDrafts(nextSnapshot)
        await refreshSavedFilters()
        guard session == vaultSession, epoch == modelEpoch else { return }
        await refreshAppearance()
        guard session == vaultSession, epoch == modelEpoch else { return }
        await refreshConfigurationSettings()
        guard session == vaultSession, epoch == modelEpoch else { return }
        if let selectedTaskPath, nextSnapshot.tasks[selectedTaskPath] == nil {
            if taskDrafts[selectedTaskPath]?.isDirty != true {
                self.selectedTaskPath = nil
            }
        }
    }
}

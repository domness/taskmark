import Foundation

extension WorkspaceModel {
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
            await refreshSavedFilters()
            await refreshAppearance()
            await refreshConfigurationSettings()
            if let selectedTaskPath, nextSnapshot.tasks[selectedTaskPath] == nil {
                if taskDrafts[selectedTaskPath]?.isDirty != true {
                    self.selectedTaskPath = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

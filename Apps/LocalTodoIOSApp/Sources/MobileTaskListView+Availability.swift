import LocalTodoMarkdown

extension MobileTaskListView {
    var vaultAvailabilityMessage: String? {
        guard workspace.snapshot?.scanCompleteness != .complete else { return nil }
        let isDownloading = workspace.snapshot?.availability.values.contains { availability in
            if case .downloading = availability {
                return true
            }
            return false
        } ?? false
        return isDownloading ? "Downloading vault files" : "Vault data is incomplete"
    }
}

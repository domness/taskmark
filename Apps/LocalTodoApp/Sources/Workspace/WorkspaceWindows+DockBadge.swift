import LocalTodoDomain
import Observation

extension WorkspaceWindows {
    /// The single Dock tile follows the same vault context as Settings, independent of the visible route.
    var dockBadgeLabel: String? {
        let model = settingsWorkspace
        guard model.preferences.showsDockBadge, let snapshot = model.snapshot else { return nil }
        do {
            let today = try model.today(configuration: snapshot.configuration, now: model.clock())
            let query = TaskQuery(scope: .today)
            let count = snapshot.tasks.values.count { query.matches($0.value, today: today) }
            return count == 0 ? nil : String(count)
        } catch {
            // An unrepresentable calendar day cannot produce a trustworthy count.
            return nil
        }
    }

    func startDockBadgeUpdates(_ update: @escaping @MainActor (String?) -> Void) {
        guard dockBadgeUpdate == nil else { return }
        dockBadgeUpdate = update
        observeDockBadge()
    }

    private func observeDockBadge() {
        let label = withObservationTracking {
            dockBadgeLabel
        } onChange: { [weak self] in
            // Observation fires before the new value is stored. Re-arm on the main actor after the change.
            Task { @MainActor [weak self] in self?.observeDockBadge() }
        }
        dockBadgeUpdate?(label)
    }
}

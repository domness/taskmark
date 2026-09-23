import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
struct DockBadgeTests {
    @Test func countMatchesTodayRegardlessOfRouteAndCountsPairedDatesOnce() throws {
        let model = WorkspaceModel(clock: { Date(timeIntervalSince1970: 1_790_164_800) })
        model.snapshot = try snapshot([
            task("Scheduled", scheduled: "2026-09-23"),
            task("Deadline", deadline: "2026-09-23"),
            task("Overdue", scheduled: "2026-09-21", deadline: "2026-09-22"),
            task("Mixed", scheduled: "2026-09-22", deadline: "2026-10-01"),
            task("Future", scheduled: "2026-10-01"),
            task("Undated"),
            task("Done", status: .done, scheduled: "2026-09-22"),
            task("Canceled", status: .canceled, deadline: "2026-09-22"),
        ])
        let windows = WorkspaceWindows()
        windows.activate(model)
        #expect(windows.dockBadgeLabel == nil)
        model.preferences.showsDockBadge = true
        #expect(windows.dockBadgeLabel == "4")
        #expect(model.visibleTasks.count == 4)
        model.route = .search
        model.searchText = "no matching task"
        #expect(model.visibleTasks.isEmpty)
        #expect(windows.dockBadgeLabel == "4")
        model.preferences.showsDockBadge = false
        #expect(windows.dockBadgeLabel == nil)
    }

    @Test func observationTracksVaultActivationPreferencesSnapshotsAndClosing() async throws {
        let first = WorkspaceModel()
        let second = WorkspaceModel()
        first.snapshot = try snapshot([task("First", scheduled: "2000-01-01")])
        second.snapshot = try snapshot([
            task("Second", deadline: "2000-01-01"), task("Third", scheduled: "2000-01-01"),
        ])
        let windows = WorkspaceWindows()
        var label: String?
        windows.startDockBadgeUpdates { label = $0 }
        windows.activate(first)
        first.preferences.showsDockBadge = true
        try await waitForBadge("1", reading: { label })
        windows.activate(second)
        try await waitForBadge(nil, reading: { label })
        second.preferences.showsDockBadge = true
        try await waitForBadge("2", reading: { label })
        second.snapshot = snapshot([])
        try await waitForBadge(nil, reading: { label })
        windows.remove(second)
        try await waitForBadge("1", reading: { label })
        first.releaseWindowResources()
        try await waitForBadge(nil, reading: { label })
        windows.remove(first)
        #expect(windows.dockBadgeLabel == nil)
    }

    @Test func refreshReevaluatesBadgeAtVaultLocalMidnight() async throws {
        var now = try #require(ISO8601DateFormatter().date(from: "2026-09-23T06:59:59Z"))
        let model = WorkspaceModel(clock: { now })
        let tasks = try [task("Tomorrow locally", deadline: "2026-09-23")]
        model.snapshot = snapshot(tasks, timezone: "America/Los_Angeles")
        model.preferences.showsDockBadge = true
        let windows = WorkspaceWindows()
        windows.activate(model)
        var label: String?
        windows.startDockBadgeUpdates { label = $0 }
        #expect(label == nil)
        now = now.addingTimeInterval(1)
        // The existing refresh loop republishes the vault snapshot every two seconds.
        model.snapshot = snapshot(tasks, timezone: "America/Los_Angeles", generation: 2)
        try await waitForBadge("1", reading: { label })
        model.snapshot = snapshot(tasks, timezone: "Pacific/Honolulu", generation: 3)
        try await waitForBadge(nil, reading: { label })
    }

    @Test func badgeUpdatesAfterCompletionAndExternalPreferenceReload() async throws {
        try await withWorkspace { model, root in
            let windows = WorkspaceWindows()
            windows.activate(model)
            var label: String?
            windows.startDockBadgeUpdates { label = $0 }
            model.preferences.showsDockBadge = true
            await model.createTask(title: "Due today", vaultSession: model.vaultSession, captureRoute: .today)
            try await waitForBadge("1", reading: { label })
            let draft = try #require(model.selectedTaskDraft)
            draft.status = .done
            #expect(await model.flushTaskChanges())
            try await waitForBadge(nil, reading: { label })
            draft.status = .next
            #expect(await model.flushTaskChanges())
            try await waitForBadge("1", reading: { label })
            let store = VaultStore(root: root)
            let record = try await store.configurationRecord()
            _ = try await store.setPreferences(["dock_badge": .bool(false)], expectedRevision: record.revision)
            await model.refresh()
            try await waitForBadge(nil, reading: { label })
            #expect(!model.preferences.showsDockBadge)
        }
    }

    private func waitForBadge(_ expected: String?, reading: () -> String?) async throws {
        for _ in 0 ..< 100 where reading() != expected {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(reading() == expected)
    }

    private func task(
        _ title: String, status: TaskStatus = .next, scheduled: String? = nil, deadline: String? = nil
    ) throws -> TodoTask {
        try TodoTask(
            path: VaultPath("Tasks/\(title).md"), title: title, status: status,
            scheduled: scheduled.map(CalendarDate.init), deadline: deadline.map(CalendarDate.init),
            createdAt: .distantPast, updatedAt: .distantPast,
            completedAt: status == .done ? .distantPast : nil
        )
    }

    private func snapshot(
        _ tasks: [TodoTask], timezone: String = "UTC", generation: UInt64 = 1
    ) -> VaultSnapshot {
        VaultSnapshot(
            generation: generation, configuration: VaultConfiguration(timezone: timezone),
            tasks: Dictionary(uniqueKeysWithValues: tasks.map {
                ($0.path, VaultRecord(value: $0, revision: FileRevision(data: Data($0.title.utf8))))
            }), projects: [:], areas: [:], diagnostics: []
        )
    }
}

import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
struct SidebarCountTests {
    @Test func countsMatchDestinationsAndIgnoreActiveSearch() throws {
        let model = WorkspaceModel(clock: { Date(timeIntervalSince1970: 1_790_164_800) })
        let project = try VaultPath("Projects/Work.md")
        let area = try VaultPath("Areas/Work.md")
        let active = try TodoTask(
            path: VaultPath("Tasks/Active.md"), title: "Active", status: .next, priority: .p1,
            scheduled: CalendarDate("2026-09-22"), deadline: CalendarDate("2026-10-01"),
            project: project, area: area, tags: ["work"], createdAt: .distantPast, updatedAt: .distantPast
        )
        let done = try TodoTask(
            path: VaultPath("Tasks/Done.md"), title: "Done", status: .done, priority: .p1,
            project: project, area: area, tags: ["work"], createdAt: .distantPast,
            updatedAt: .distantPast, completedAt: .distantPast
        )
        model.snapshot = try snapshot([
            active, done, task("Canceled", status: .canceled), task("Inbox", status: .inbox),
            task("Waiting", status: .waiting), task("Someday", status: .someday),
        ])
        let routes: [WorkspaceRoute] = [
            .today, .upcoming, .next, .inbox, .waiting, .someday,
            .project(project), .area(area), .tag("work"), .priority(.p1),
        ]
        for route in routes {
            model.route = route
            #expect(model.sidebarTaskCount(for: route) == 1)
            #expect(model.sidebarTaskCount(for: route) == model.visibleTasks.count)
        }
        model.route = .search
        model.searchText = "no matching tasks"
        #expect(model.visibleTasks.isEmpty)
        #expect(model.sidebarTaskCount(for: .today) == 1)
        #expect(model.sidebarTaskCount(for: .priority(nil)) == 3)
        #expect(model.sidebarTaskCount(for: .tag("empty")) == 0)
        for route: WorkspaceRoute in [.all, .search, .filters, .issues] {
            #expect(model.sidebarTaskCount(for: route) == nil)
        }
    }

    @Test func savedCountsRespectCompletionAndSuppressUnavailableDefinitions() throws {
        let model = WorkspaceModel()
        model.snapshot = try snapshot([task("Done", status: .done), task("Active", status: .next)])
        var filters = TaskFilters()
        filters.statuses = [.done]
        let completed = try SavedTaskFilter(
            name: "Completed", query: TaskQuery(filters: filters, includeCompleted: true)
        )
        model.filterState.record = SavedFilterRecord(filters: [completed])
        #expect(model.sidebarTaskCount(for: .savedFilter("Completed")) == 1)
        #expect(model.sidebarTaskCount(for: .savedFilter("Missing")) == nil)
        model.filterState.loadError = "Malformed filters"
        #expect(model.sidebarTaskCount(for: .savedFilter("Completed")) == nil)
        model.snapshot = nil
        #expect(model.sidebarTaskCount(for: .inbox) == nil)
    }

    @Test func countsFollowSnapshotChangesAndVaultLocalMidnight() throws {
        var now = try #require(ISO8601DateFormatter().date(from: "2026-09-23T06:59:59Z"))
        let model = WorkspaceModel(clock: { now })
        let due = try TodoTask(
            path: VaultPath("Tasks/Due.md"), title: "Due", status: .next,
            deadline: CalendarDate("2026-09-23"), createdAt: .distantPast, updatedAt: .distantPast
        )
        model.snapshot = snapshot([due], timezone: "America/Los_Angeles")
        #expect(model.sidebarTaskCount(for: .today) == 0)
        #expect(model.sidebarTaskCount(for: .upcoming) == 1)
        now = now.addingTimeInterval(1)
        model.snapshot = snapshot([due], timezone: "America/Los_Angeles", generation: 2)
        #expect(model.sidebarTaskCount(for: .today) == 1)
        #expect(model.sidebarTaskCount(for: .upcoming) == 0)
        model.snapshot = snapshot([], generation: 3)
        #expect(model.sidebarTaskCount(for: .today) == 0)
    }

    @Test func completingAndReopeningTaskUpdatesCounts() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Task", vaultSession: model.vaultSession, captureRoute: .today)
            #expect(model.sidebarTaskCount(for: .today) == 1)
            let draft = try #require(model.selectedTaskDraft)
            draft.status = .done
            #expect(await model.flushTaskChanges())
            #expect(model.sidebarTaskCount(for: .today) == 0)
            draft.status = .next
            #expect(await model.flushTaskChanges())
            #expect(model.sidebarTaskCount(for: .today) == 1)
        }
    }

    private func task(_ title: String, status: TaskStatus) throws -> TodoTask {
        try TodoTask(
            path: VaultPath("Tasks/\(title).md"), title: title, status: status,
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

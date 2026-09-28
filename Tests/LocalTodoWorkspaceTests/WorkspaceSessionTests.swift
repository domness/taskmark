import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import LocalTodoWorkspace
import Testing

@MainActor
struct WorkspaceSessionTests {
    @Test func captureUsesRouteDefaultsAndCollisionSafePaths() async throws {
        try await withVault { root in
            let now = try #require(ISO8601DateFormatter().date(from: "2026-09-28T12:00:00Z"))
            let session = WorkspaceSession(clock: { now })
            try await session.open(root: root)

            let first = try await session.capture(title: "Plan launch", route: .today)
            let second = try await session.capture(title: "Plan launch", route: .inbox)
            let expectedDate = try CalendarDate("2026-09-28")

            #expect(first.value == "Tasks/plan-launch.md")
            #expect(second.value == "Tasks/plan-launch-2.md")
            #expect(session.snapshot?.tasks[first]?.value.status == .next)
            #expect(session.snapshot?.tasks[first]?.value.scheduled == expectedDate)
            #expect(session.snapshot?.tasks[second]?.value.status == .inbox)
        }
    }

    @Test func taskMutationsRoundTripThroughCanonicalStore() async throws {
        try await withVault { root in
            let session = WorkspaceSession()
            try await session.open(root: root)
            let path = try await session.capture(title: "Draft", route: .inbox)
            var patch = TaskPatch()
            patch.title = .set("Ready")
            patch.body = .set("Body remains Markdown.\n")
            try await session.updateTask(at: path, patch: patch)
            try await session.toggleCompletion(at: path)

            let reloaded = try await VaultStore(root: root).snapshot().tasks[path]?.value
            #expect(reloaded?.title == "Ready")
            #expect(reloaded?.body == "Body remains Markdown.\n")
            #expect(reloaded?.status == .done)
        }
    }

    @Test func persistedHistoryRestoresExactBytesAndNeverOverwritesAnOccupiedPath() async throws {
        try await withVault { root in
            let session = WorkspaceSession(clock: { Date(timeIntervalSince1970: 100) })
            try await session.open(root: root)
            let path = try await session.capture(title: "Undo me", route: .inbox)
            let original = try Data(contentsOf: root.appendingPathComponent(path.value))
            #expect(session.canUndo)

            try await session.undo()
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(path.value).path))
            #expect(session.canRedo)

            try await session.redo()
            #expect(try Data(contentsOf: root.appendingPathComponent(path.value)) == original)

            try await session.undo()
            try Data("occupied".utf8).write(to: root.appendingPathComponent(path.value), options: .atomic)
            await #expect(throws: VaultStoreError.destinationExists(path)) {
                try await session.redo()
            }
            #expect(try Data(contentsOf: root.appendingPathComponent(path.value)) == Data("occupied".utf8))
            #expect(!session.canRedo)
        }
    }

    @Test func duplicateAndPreferencesUseCanonicalStoreContracts() async throws {
        try await withVault { root in
            let session = WorkspaceSession()
            try await session.open(root: root)
            let original = try await session.capture(title: "Keep metadata", route: .inbox)
            let copy = try await session.duplicateTask(at: original)

            try await session.setPreferences([
                "appearance": .string("dark"),
                "future_mobile_setting": .object(["enabled": .bool(true)]),
            ])
            try await session.setPreferences(["theme": .string("forest")])

            let reloaded = try await VaultStore(root: root).snapshot()
            #expect(copy.value == "Tasks/keep-metadata-copy.md")
            #expect(reloaded.tasks[copy]?.value.title == "Keep metadata (Copy)")
            #expect(reloaded.configuration.preferences["appearance"] == .string("dark"))
            #expect(reloaded.configuration.preferences["theme"] == .string("forest"))
            #expect(reloaded.configuration.preferences["future_mobile_setting"] == .object(["enabled": .bool(true)]))
        }
    }

    @Test func checkpointsStayVaultBoundAndGenerationSafe() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TaskDraftCheckpointStore(fileURL: root.appendingPathComponent("drafts.json"))
        let path = try VaultPath("Tasks/draft.md")
        let first = TaskDraftCheckpoint(
            vaultIdentifier: "vault-a", path: path, baseRevision: "base", generation: 1,
            title: "First", status: .inbox, priority: nil, scheduled: nil, deadline: nil,
            project: nil, area: nil, tags: [], body: ""
        )
        let latest = TaskDraftCheckpoint(
            vaultIdentifier: "vault-a", path: path, baseRevision: "base", generation: 2,
            title: "Latest", status: .next, priority: .p1, scheduled: nil, deadline: nil,
            project: nil, area: nil, tags: ["mobile"], body: "Draft"
        )
        let otherVault = TaskDraftCheckpoint(
            vaultIdentifier: "vault-b", path: path, baseRevision: "other", generation: 1,
            title: "Other", status: .inbox, priority: nil, scheduled: nil, deadline: nil,
            project: nil, area: nil, tags: [], body: ""
        )

        try await store.save(first)
        try await store.save(latest)
        try await store.save(otherVault)
        try await store.remove(vaultIdentifier: "vault-a", path: path, through: 1)
        #expect(try await store.checkpoints().contains(latest))
        try await store.remove(vaultIdentifier: "vault-a", path: path, through: 2)
        let remaining = try await store.checkpoints()
        #expect(remaining == [otherVault])
    }

    @Test func legacyTaskCheckpointDefaultsNewRecurrenceFields() throws {
        let current = try TaskDraftCheckpoint(
            vaultIdentifier: "vault",
            path: VaultPath("Tasks/task.md"),
            baseRevision: "base",
            generation: 1,
            title: "Task",
            status: .inbox,
            priority: nil,
            scheduled: nil,
            deadline: nil,
            project: nil,
            area: nil,
            tags: [],
            body: "Notes"
        )
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        object.removeValue(forKey: "recurrence")
        object.removeValue(forKey: "resetChecklistOnRepeat")
        let data = try JSONSerialization.data(withJSONObject: [object])

        let checkpoint = try #require(JSONDecoder().decode([TaskDraftCheckpoint].self, from: data).first)

        #expect(checkpoint.recurrence == RecurrenceEditorValue(nil))
        #expect(!checkpoint.resetChecklistOnRepeat)
    }

    @Test func collectionLifecycleUsesProtectedCanonicalEntities() async throws {
        try await withVault { root in
            let session = WorkspaceSession()
            try await session.open(root: root)
            let area = try await session.createCollection(kind: .area, title: "Personal")
            let project = try await session.createCollection(kind: .project, title: "Ship iOS")
            var patch = ProjectPatch()
            patch.area = .set(area)
            patch.body = .set("# Outcome\n")
            try await session.updateProject(at: project, patch: patch)
            _ = try await session.capture(title: "Test app", route: .project(project))

            await #expect(throws: (any Error).self) {
                try await session.deleteCollection(at: project)
            }
            #expect(session.snapshot?.projects[project]?.value.area == area)
            #expect(session.snapshot?.projects[project]?.value.body == "# Outcome\n")
        }
    }

    @Test func savedFiltersRunAndUseWholeDocumentRevisions() async throws {
        try await withVault { root in
            let first = WorkspaceSession()
            let second = WorkspaceSession()
            try await first.open(root: root)
            try await second.open(root: root)
            _ = try await first.capture(title: "Urgent", route: .inbox)
            _ = try await first.capture(title: "Later", route: .someday)
            let inbox = try SavedTaskFilter(name: "Inbox only", query: TaskQuery(scope: .inbox))
            try await first.saveFilter(inbox)

            #expect(first.tasks(for: .savedFilter("Inbox only")).map(\.title) == ["Urgent"])
            let stale = try SavedTaskFilter(name: "Stale", query: TaskQuery(scope: .all))
            await #expect(throws: SavedFilterError.conflict) { try await second.saveFilter(stale) }
            #expect(first.savedFilters.filters.map(\.name) == ["Inbox only"])
        }
    }

    @Test func viewOptionsAndCustomOrderUseExactSharedRouteKeys() async throws {
        try await withVault { root in
            let session = WorkspaceSession()
            try await session.open(root: root)
            let first = try await session.capture(title: "First", route: .inbox)
            let second = try await session.capture(title: "Second", route: .inbox)
            let route = WorkspaceRoute.inbox
            let options = WorkspaceViewOptions(
                showsProject: false, showsArea: true, showsTags: false, grouping: .area, sort: .title
            )
            try await session.setViewOptions(options, for: route)
            try await session.setCustomOrder(
                WorkspaceCustomOrder(isEnabled: true, paths: [second, first]), for: route
            )

            #expect(session.viewOptions(for: route) == options)
            #expect(session.tasks(for: route).map(\.path) == [second, first])
            let preferences = try await VaultStore(root: root).snapshot().configuration.preferences
            guard case let .object(views) = preferences["views"], views["inbox"] != nil,
                  case let .object(orders) = preferences["custom_order"], orders["inbox"] != nil
            else {
                Issue.record("Expected exact shared inbox preference keys")
                return
            }
        }
    }

    private func withVault(_ operation: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try VaultInitializer.initialize(at: root, timezone: "Europe/London")
        try await operation(root)
    }
}

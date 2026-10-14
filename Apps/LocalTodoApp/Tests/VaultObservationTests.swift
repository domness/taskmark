import AppKit
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
struct VaultObservationTests {
    @Test func eventsReloadNestedFilesAtomicReplacementMovesAndDeletion() async throws {
        try await withWorkspace { model, root in
            let path = try VaultPath("Nested/External.md")
            let store = VaultStore(root: root)
            let task = try TodoTask(path: path, title: "External", status: .inbox, createdAt: Date(), updatedAt: Date())
            _ = try await store.create(.task(task))
            try await waitForRefreshCondition { model.snapshot?.tasks[path]?.value.title == "External" }
            let url = root.appendingPathComponent(path.value)
            let original = try String(contentsOf: url, encoding: .utf8)
            try original.replacingOccurrences(of: "External", with: "Replaced").write(
                to: url, atomically: true, encoding: .utf8
            )
            try await waitForRefreshCondition { model.snapshot?.tasks[path]?.value.title == "Replaced" }
            let moved = try VaultPath("Nested/Moved.md")
            try FileManager.default.moveItem(at: url, to: root.appendingPathComponent(moved.value))
            try await waitForRefreshCondition {
                model.snapshot?.tasks[path] == nil && model.snapshot?.tasks[moved] != nil
            }
            try Data("---\ntype: [\n---\n".utf8).write(to: root.appendingPathComponent(moved.value))
            try await waitForRefreshCondition { model.snapshot?.diagnostics.contains { $0.path == moved } == true }
            try FileManager.default.removeItem(at: root.appendingPathComponent(moved.value))
            try await waitForRefreshCondition {
                model.snapshot?.tasks[moved] == nil && model.snapshot?.diagnostics.isEmpty == true
            }
        }
    }

    @Test func eventsIncludeHiddenConfigurationFiltersAndStylesheet() async throws {
        try await withWorkspace { model, root in
            let store = VaultStore(root: root)
            let record = try await store.configurationRecord()
            _ = try await store.setPreferences(["dock_badge": .bool(true)], expectedRevision: record.revision)
            try await waitForRefreshCondition { model.preferences.showsDockBadge }
            let filters = "---\nschema: 1\nfilters:\n  - name: External\n    view: inbox\n---\n"
            try filters.write(to: root.appendingPathComponent(".config/filters.md"), atomically: true, encoding: .utf8)
            try await waitForRefreshCondition { model.filterState.record?.filters.first?.name == "External" }
            try Data("not a valid stylesheet".utf8).write(to: root.appendingPathComponent(".config/style.css"))
            try await waitForRefreshCondition { model.stylesheetDiagnostic != nil }
        }
    }

    @Test func fallbackRefreshWorksWithoutFileEvents() async throws {
        try await withWorkspace { model, root in
            model.startVaultObservation(fallbackInterval: .milliseconds(100), tolerance: .zero)
            model.vaultObserver = nil
            let store = VaultStore(root: root)
            let record = try await store.configurationRecord()
            _ = try await store.setPreferences(["dock_badge": .bool(true)], expectedRevision: record.revision)
            try await waitForRefreshCondition { model.preferences.showsDockBadge }
        }
    }

    @Test func wakeRefreshesWithoutFileEventsAndCloseCancelsObservation() async throws {
        try await withWorkspace { model, root in
            model.stopVaultObservation()
            model.startVaultObservation()
            model.vaultObserver = nil
            let store = VaultStore(root: root)
            let record = try await store.configurationRecord()
            _ = try await store.setPreferences(["dock_badge": .bool(true)], expectedRevision: record.revision)
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
            try await waitForRefreshCondition { model.preferences.showsDockBadge }
            model.scheduleExternalRefresh()
            model.releaseWindowResources()
            #expect(model.vaultObserver == nil)
            #expect(model.lifecycleObserver == nil)
            #expect(model.externalRefreshTask == nil)
            #expect(model.refreshLoop == nil)
            #expect(model.dayChangeTask == nil)
            #expect(model.snapshot == nil)
        }
    }

    @Test func switchingVaultsDiscardsOldEvents() async throws {
        try await withWorkspace { model, oldRoot in
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try VaultInitializer.initialize(at: root)
            defer { try? FileManager.default.removeItem(at: root) }
            model.scheduleExternalRefresh()
            #expect(try await model.openVault(root))
            let oldStore = VaultStore(root: oldRoot)
            let record = try await oldStore.configurationRecord()
            _ = try await oldStore.setPreferences(["dock_badge": .bool(true)], expectedRevision: record.revision)
            let newStore = VaultStore(root: root)
            let newRecord = try await newStore.configurationRecord()
            _ = try await newStore.setPreferences(["theme": .string("forest")], expectedRevision: newRecord.revision)
            try await waitForRefreshCondition { model.preferences.theme == .forest }
            #expect(!model.preferences.showsDockBadge)
            #expect(model.rootURL == root)
            model.releaseWindowResources()
        }
    }
}

import Foundation
@testable import LocalTodoApp
import LocalTodoMarkdown
import Testing

@MainActor
@Test func copiedVaultCarriesAllPreferencesAndOrdersToAnotherMachine() async throws {
    try await withWorkspace { model, root in
        model.route = .inbox
        for title in ["A", "B"] {
            await model.createTask(title: title, vaultSession: model.vaultSession)
        }
        for title in ["A", "B"] {
            await model.createCollection(kind: .project, path: "Projects/\(title).md", title: title)
        }
        model.preferences.theme = .forest
        model.preferences.appearance = .dark
        model.preferences.weekStart = .saturday
        model.preferences.dateFormat = .iso
        model.preferences.timeFormat = .twentyFourHour
        model.preferences.initialView = .waiting
        model.preferences.usesVaultStylesheet = false
        model.preferences.showsDockBadge = true
        try model.moveCollection(#require(model.activeProjects.last?.path), in: .project, offset: -1)
        model.route = .inbox
        model.setTaskListSort(.custom)
        #expect(model.moveTasks(from: [0], to: 2, context: model.taskReorderContext(for: model.visibleTasks)))
        model.setTaskListMetadata(.tags, isVisible: false)
        model.setTaskListGrouping(.project)
        #expect(await model.flushTaskChanges())
        let copy = root.deletingLastPathComponent().appendingPathComponent("copied-vault-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.copyItem(at: root, to: copy)
        try await withReloadedWorkspace(copy) { other in
            #expect(other.preferences.values == model.preferences.values)
            #expect(other.route == .waiting)
            #expect(other.orderedCollectionPaths(.project) == model.orderedCollectionPaths(.project))
            other.route = .inbox
            #expect(other.currentTaskListSort == .custom)
            #expect(other.visibleTasks.map(\.title) == ["B", "A"])
            #expect(!other.currentTaskListDisplayOptions.showsTags)
            #expect(other.currentTaskListDisplayOptions.grouping == .project)
        }
    }
}

@MainActor
@Test func separateClientsMergeDifferentPreferencesAndReloadExternalTheme() async throws {
    try await withWorkspace { model, root in
        let other = WorkspaceModel()
        let opened = try await other.openVault(root)
        #expect(opened)
        model.preferences.theme = .forest
        other.preferences.dateFormat = .iso
        #expect(await model.flushPreferences())
        #expect(await other.flushPreferences())
        await model.refresh()
        #expect(model.preferences.dateFormat == .iso)
        #expect(other.preferences.theme == .forest)
        other.preferences.theme = .slate
        #expect(await other.flushPreferences())
        await model.refresh()
        #expect(model.preferences.theme == .slate)
    }
}

@MainActor
@Test(arguments: [false, true])
func conflictingPreferenceEditsRequireExplicitResolution(keepLocal: Bool) async throws {
    try await withWorkspace { model, root in
        let other = WorkspaceModel()
        let opened = try await other.openVault(root)
        #expect(opened)
        model.preferences.theme = .forest
        other.preferences.theme = .sand
        #expect(await model.flushPreferences())
        #expect(await !(other.flushPreferences()))
        #expect(other.preferenceConflicts == ["theme"])
        #expect(other.preferences.theme == .sand)
        #expect(try await VaultStore(root: root).configurationRecord().value.preferences["theme"] == .string("forest"))
        if keepLocal {
            await other.keepPreferenceChanges()
        } else {
            await other.discardPreferenceChanges()
        }
        #expect(other.pendingPreferenceChanges.isEmpty)
        #expect(other.preferences.theme == (keepLocal ? .sand : .forest))
        await model.refresh()
        #expect(model.preferences.theme == other.preferences.theme)
    }
}

@MainActor
@Test(arguments: [false, true])
func keepingLocalViewPreferencesPreservesExternalExtensionMetadata(removeViews: Bool) async throws {
    try await withWorkspace { model, root in
        let store = VaultStore(root: root)
        let original = try await store.configurationRecord()
        let inboxPreferences: ConfigurationValue = .object([
            "showsProject": .bool(true), "showsArea": .bool(true), "showsTags": .bool(true),
            "grouping": .string("none"), "plugin": .string("A"),
        ])
        let first = try await store.setPreferences(
            ["views": .object(["inbox": inboxPreferences])], expectedRevision: original.revision
        )
        await model.refresh()
        model.route = .inbox
        model.setTaskListMetadata(.tags, isVisible: false)
        if removeViews {
            let source = try VaultConfiguration(timezone: "Europe/London").encoded()
            try Data(source.utf8).write(to: root.appendingPathComponent(LocalTodoSchema.manifestPath))
        } else {
            _ = try await store.setPreferences(
                ["views": .object(["inbox": .object(["plugin": .string("B")])])],
                expectedRevision: first.revision
            )
        }
        #expect(await !(model.flushPreferences()))
        await model.keepPreferenceChanges()
        #expect(model.pendingPreferenceChanges.isEmpty)
        let saved = try await store.configurationRecord()
        guard case let .object(views) = saved.value.preferences["views"],
              case let .object(inbox) = views["inbox"] else { Issue.record("Missing view preferences"); return }
        #expect(inbox["plugin"] == .string(removeViews ? "A" : "B"))
        #expect(inbox["showsTags"] == .bool(false))
    }
}

@MainActor
@Test func malformedConfigurationAndFailedWritesRetainPendingPreferences() async throws {
    try await withWorkspace { model, root in
        let url = root.appendingPathComponent(LocalTodoSchema.manifestPath)
        let original = try Data(contentsOf: url)
        let malformed = Data("schema: 2\npreferences: {theme: [invalid]}\n".utf8)
        model.preferences.theme = .forest
        try malformed.write(to: url)
        #expect(await !(model.flushPreferences()))
        #expect(model.hasPendingDocumentChanges)
        #expect(try Data(contentsOf: url) == malformed)
        try original.write(to: url)
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        #expect(await !(model.flushPreferences()))
        #expect(try Data(contentsOf: url) == original)
        model.store = VaultStore(root: root)
        #expect(await model.flushPreferences())
        #expect(try await VaultStore(root: root).configurationRecord().value.preferences["theme"] == .string("forest"))
    }
}

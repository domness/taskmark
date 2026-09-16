import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func filterSaveConflictKeepsWorkingCriteriaAndExternalDefinitions() async throws {
    try await withWorkspace { model, root in
        model.beginFilterEditing()
        model.filterState.name = "Mine"
        model.filterState.editor.tags = "work"
        let external = try SavedTaskFilter(name: "External", query: TaskQuery(scope: .waiting))
        _ = try await VaultStore(root: root).saveFilters([external], expectedRevision: nil)
        await model.refresh()
        await model.saveWorkingFilter()
        #expect(model.filterState.hasConflict)
        #expect(model.filterState.editor.tags == "work")
        #expect(try await VaultStore(root: root).savedFilters().filters == [external])
        await model.keepWorkingFilterAfterReload()
        await model.saveWorkingFilter()
        #expect(!model.filterState.hasConflict)
        #expect(try await VaultStore(root: root).savedFilters().filters.map(\.name) == ["External", "Mine"])
    }
}

@MainActor
@Test func filterWriteFailureRetainsWorkingStateForRetry() async throws {
    try await withWorkspace { model, root in
        model.beginFilterEditing()
        model.filterState.name = "Retry"
        model.filterState.editor.view = .someday
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        await model.saveWorkingFilter()
        #expect(model.filterState.saveError != nil)
        #expect(model.filterState.editor.view == .someday)
        #expect(!model.filterState.isSaving)
        let unchanged = try await VaultStore(root: root).savedFilters()
        #expect(unchanged.filters.isEmpty)
        model.store = VaultStore(root: root)
        await model.saveWorkingFilter()
        #expect(try await VaultStore(root: root).savedFilters().filters.first?.query.scope == .someday)
    }
}

@MainActor
@Test func malformedSavedFiltersAndMissingReferencesAreVisible() async throws {
    try await withWorkspace { model, root in
        var filters = TaskFilters()
        filters.project = try VaultPath("Projects/Missing.md")
        _ = try await VaultStore(root: root).saveFilters([
            SavedTaskFilter(name: "Missing", query: TaskQuery(filters: filters)),
        ], expectedRevision: nil)
        await model.refresh()
        model.route = .savedFilter("Missing")
        #expect(model.filterReferenceMessage?.contains("Projects/Missing.md") == true)
        let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
        let bytes = Data("---\nschema: 100\nfilters: []\n---\nKeep me".utf8)
        try bytes.write(to: url)
        await model.refresh()
        #expect(model.filterState.loadError != nil)
        #expect(model.currentTaskQuery == nil)
        model.beginFilterEditing(name: "Missing")
        await model.saveWorkingFilter()
        #expect(try Data(contentsOf: url) == bytes)
    }
}

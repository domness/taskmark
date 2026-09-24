import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    var currentTaskQuery: TaskQuery? {
        if route == .filters {
            return try? filterState.editor.query()
        }
        if case let .savedFilter(name) = route {
            guard filterState.loadError == nil else { return nil }
            return filterState.record?.filters.first { $0.name == name }?.query
        }
        return TaskQuery(
            scope: route.scope,
            text: route == .search ? searchText.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            includeCompleted: route == .search,
            sort: currentTaskSort
        )
    }

    var filterReferenceMessage: String? {
        guard route == .filters || isSavedFilterRoute, let query = currentTaskQuery, let snapshot,
              let filter = try? SavedTaskFilter(name: "Query", query: query) else { return nil }
        let missing = filter.missingReferences(projects: Set(snapshot.projects.keys), areas: Set(snapshot.areas.keys))
        return missing.isEmpty ? nil : "Missing filter references: \(missing.map(\.value).joined(separator: ", "))."
    }

    var isSavedFilterRoute: Bool {
        if case .savedFilter = route {
            return true
        }
        return false
    }

    func beginFilterEditing(name: String? = nil) {
        let record = filterState.record
        let query = name.flatMap { name in record?.filters.first { $0.name == name }?.query }
        guard name == nil || query != nil else {
            filterState.saveError = "That saved filter no longer exists. "
                + "Keep the working criteria or create a new filter."
            return
        }
        filterState.editor = TaskFilterEditor(query: query ?? TaskQuery(sort: .priority))
        filterState.name = name ?? ""
        filterState.editingName = name
        filterState.baseRevision = record?.revision
        filterState.saveError = nil
        filterState.hasConflict = false
        route = .filters
    }

    func refreshSavedFilters() async {
        guard let store, !filterState.isSaving else { return }
        let session = vaultSession
        filterState.readGeneration += 1
        let generation = filterState.readGeneration
        do {
            let record = try await store.savedFilters()
            guard session == vaultSession, generation == filterState.readGeneration,
                  !filterState.isSaving else { return }
            if let previous = filterState.record, previous.revision != record.revision {
                clearHistory()
            }
            filterState.record = record
            filterState.loadError = nil
        } catch {
            guard session == vaultSession, generation == filterState.readGeneration else { return }
            filterState.loadError = error.localizedDescription
        }
    }

    func keepWorkingFilterAfterReload() async {
        await refreshSavedFilters()
        guard filterState.loadError == nil, !filterState.isSaving else { return }
        filterState.baseRevision = filterState.record?.revision
        filterState.hasConflict = false
        filterState.saveError = nil
    }
}

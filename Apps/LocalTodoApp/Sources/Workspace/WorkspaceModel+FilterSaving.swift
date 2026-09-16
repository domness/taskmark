import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func saveWorkingFilter() async {
        guard let store, let record = filterState.record, !filterState.isSaving,
              filterState.loadError == nil, !filterState.hasConflict else { return }
        do {
            let filter = try validatedWorkingFilter(record)
            let updated = record.filters.filter { $0.name != filter.name } + [filter]
            filterState.isSaving = true
            filterState.readGeneration += 1
            defer { filterState.isSaving = false }
            let session = vaultSession
            let saved = try await store.saveFilters(updated, expectedRevision: filterState.baseRevision)
            guard session == vaultSession else { return }
            filterState.record = saved
            filterState.baseRevision = saved.revision
            filterState.editingName = filter.name
            filterState.saveError = nil
            registerFilterHistory(restoring: record.filters)
            if filterState.name == filter.name, (try? filterState.editor.query()) == filter.query {
                route = .savedFilter(filter.name)
            }
        } catch let error as SavedFilterError where error == .conflict {
            filterState.hasConflict = true
            filterState.saveError = error.localizedDescription
        } catch {
            filterState.saveError = error.localizedDescription
        }
    }

    private func validatedWorkingFilter(_ record: SavedFilterRecord) throws -> SavedTaskFilter {
        guard !filterState.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FilterEditingError.message("Enter a name for this filter.")
        }
        let exists = record.filters.contains { $0.name == filterState.name }
        if exists, filterState.editingName != filterState.name {
            throw FilterEditingError
                .message("That filter name already exists. Choose it from Saved Filters to edit it.")
        }
        return try SavedTaskFilter(name: filterState.name, query: filterState.editor.query())
    }

    func registerFilterHistory(restoring filters: [SavedTaskFilter]) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.performFilterHistory(restoring: filters) }
        }
        undoManager?.setActionName("Save Filter")
    }

    private func performFilterHistory(restoring filters: [SavedTaskFilter]) {
        guard let record = filterState.record, let store, !filterState.isSaving, !isHistoryBusy else { return }
        registerFilterHistory(restoring: record.filters)
        filterState.isSaving = true
        filterState.readGeneration += 1
        isHistoryBusy = true
        let session = vaultSession
        Task {
            defer { filterState.isSaving = false; isHistoryBusy = false }
            do {
                let saved = try await store.saveFilters(filters, expectedRevision: record.revision)
                guard session == vaultSession else { return }
                filterState.record = saved
                filterState.baseRevision = saved.revision
            } catch {
                clearHistory()
                filterState.saveError = error.localizedDescription
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum FilterEditingError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}

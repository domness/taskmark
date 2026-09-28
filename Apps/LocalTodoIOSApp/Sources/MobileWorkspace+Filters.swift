import LocalTodoDomain
import LocalTodoMarkdown

extension MobileWorkspace {
    enum FilterSaveResult { case saved, conflict, failed }

    var savedFilters: [SavedTaskFilter] {
        session.savedFilters.filters
    }

    func saveFilter(_ filter: SavedTaskFilter, replacing originalName: String?) async -> FilterSaveResult {
        do {
            try await session.saveFilter(filter, replacing: originalName)
            return .saved
        } catch SavedFilterError.conflict {
            return .conflict
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    func resolveFilterConflictKeepingLocal(
        _ filter: SavedTaskFilter,
        replacing originalName: String?
    ) async -> Bool {
        do {
            try await session.resolveFilterConflictKeepingLocal(filter, replacing: originalName)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteFilter(named name: String) async -> Bool {
        do {
            try await session.deleteFilter(named: name)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

import LocalTodoDomain
import LocalTodoMarkdown

public extension WorkspaceSession {
    internal func loadSavedFilters(from store: VaultStore) async {
        do {
            savedFilters = try await store.savedFilters()
            savedFilterError = nil
        } catch {
            savedFilters = SavedFilterRecord()
            savedFilterError = error.localizedDescription
        }
    }

    internal func savedQuery(for route: WorkspaceRoute) -> TaskQuery? {
        guard case let .savedFilter(name) = route else { return nil }
        return savedFilters.filters.first { $0.name == name }?.query
    }

    func saveFilter(_ filter: SavedTaskFilter, replacing originalName: String? = nil) async throws {
        guard let store else { throw WorkspaceSessionError.noVault }
        guard savedFilterError == nil else { throw WorkspaceSessionError.savedFiltersUnavailable }
        var updated = savedFilters.filters.filter { $0.name != (originalName ?? filter.name) }
        guard !updated.contains(where: { $0.name == filter.name }) else {
            throw WorkspaceSessionError.duplicateFilterName(filter.name)
        }
        updated.append(filter)
        isSaving = true
        defer { isSaving = false }
        savedFilters = try await store.saveFilters(updated, expectedRevision: savedFilters.revision)
    }

    func deleteFilter(named name: String) async throws {
        guard let store else { throw WorkspaceSessionError.noVault }
        guard savedFilterError == nil else { throw WorkspaceSessionError.savedFiltersUnavailable }
        let updated = savedFilters.filters.filter { $0.name != name }
        guard updated.count != savedFilters.filters.count else { return }
        isSaving = true
        defer { isSaving = false }
        savedFilters = try await store.saveFilters(updated, expectedRevision: savedFilters.revision)
    }

    func resolveFilterConflictKeepingLocal(
        _ filter: SavedTaskFilter,
        replacing originalName: String?
    ) async throws {
        guard let store else { throw WorkspaceSessionError.noVault }
        await loadSavedFilters(from: store)
        try await saveFilter(filter, replacing: originalName)
    }
}

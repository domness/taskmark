import LocalTodoDomain

extension WorkspaceModel {
    /// Counts destination membership, independent of the active route or temporary search criteria.
    func sidebarTaskCount(for route: WorkspaceRoute) -> Int? {
        let query: TaskQuery
        switch route {
        case .all, .search, .filters, .issues:
            return nil
        case let .savedFilter(name):
            guard filterState.loadError == nil,
                  let savedQuery = filterState.record?.filters.first(where: { $0.name == name })?.query
            else { return nil }
            query = savedQuery
        default:
            query = TaskQuery(scope: route.scope)
        }
        guard let snapshot else { return nil }
        do {
            let today = try today(configuration: snapshot.configuration, now: clock())
            return snapshot.tasks.values.count { query.matches($0.value, today: today) }
        } catch {
            // An unrepresentable vault-local day cannot produce a trustworthy count.
            return nil
        }
    }
}

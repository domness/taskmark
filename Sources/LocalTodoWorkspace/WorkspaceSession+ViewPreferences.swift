import LocalTodoDomain
import LocalTodoMarkdown

public extension WorkspaceSession {
    func viewOptions(for route: WorkspaceRoute) -> WorkspaceViewOptions {
        guard case let .object(views) = snapshot?.configuration.preferences["views"] else { return .init() }
        return WorkspaceViewOptions(views[route.listPreferencesKey])
    }

    func customOrder(for route: WorkspaceRoute) -> WorkspaceCustomOrder {
        guard case let .object(orders) = snapshot?.configuration.preferences["custom_order"] else { return .init() }
        return WorkspaceCustomOrder(orders[route.listPreferencesKey])
    }

    func setViewOptions(_ options: WorkspaceViewOptions, for route: WorkspaceRoute) async throws {
        try await setPreferences([
            "views": .object([route.listPreferencesKey: options.configurationValue]),
        ])
    }

    func setCustomOrder(_ order: WorkspaceCustomOrder, for route: WorkspaceRoute) async throws {
        try await setPreferences([
            "custom_order": .object([route.listPreferencesKey: order.configurationValue]),
        ])
    }

    func applyingCustomOrder(_ tasks: [TodoTask], for route: WorkspaceRoute) -> [TodoTask] {
        let order = customOrder(for: route)
        guard order.isEnabled else { return tasks }
        let positions = Dictionary(uniqueKeysWithValues: order.paths.enumerated().map { ($1, $0) })
        return tasks.enumerated().sorted { lhs, rhs in
            let left = positions[lhs.element.path] ?? order.paths.count + lhs.offset
            let right = positions[rhs.element.path] ?? order.paths.count + rhs.offset
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }
}

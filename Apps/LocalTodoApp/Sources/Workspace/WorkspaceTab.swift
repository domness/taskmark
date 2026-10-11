import LocalTodoDomain

enum WorkspaceTab: Hashable, Identifiable, Sendable {
    case route(WorkspaceRoute)
    case task(VaultPath)

    var id: Self {
        self
    }

    var isTask: Bool {
        if case .task = self {
            true
        } else {
            false
        }
    }
}

struct WorkspaceTabState {
    private(set) var tabs = [WorkspaceTab]()
    private(set) var selection: WorkspaceTab?

    var isEmpty: Bool {
        tabs.isEmpty
    }

    mutating func open(_ tab: WorkspaceTab) {
        if !tabs.contains(tab) {
            tabs.append(tab)
        }
        selection = tab
    }

    mutating func open(_ tab: WorkspaceTab, preserving initialTab: WorkspaceTab) {
        if tabs.isEmpty {
            open(initialTab)
        }
        open(tab)
    }

    mutating func navigate(to route: WorkspaceRoute) {
        let destination = WorkspaceTab.route(route)
        guard let selection, let index = tabs.firstIndex(of: selection) else {
            open(destination)
            return
        }
        if tabs.contains(destination) {
            self.selection = destination
        } else {
            tabs[index] = destination
            self.selection = destination
        }
    }

    mutating func select(_ tab: WorkspaceTab) {
        guard tabs.contains(tab) else { return }
        selection = tab
    }

    mutating func close(_ tab: WorkspaceTab) {
        guard let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        guard selection == tab else { return }
        if tabs.isEmpty {
            selection = nil
        } else {
            selection = tabs[min(index, tabs.count - 1)]
        }
    }

    mutating func removeAll() {
        tabs.removeAll()
        selection = nil
    }
}

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
            guard tab != initialTab else { return }
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

    @discardableResult
    mutating func close(_ tab: WorkspaceTab) -> WorkspaceTab? {
        guard let index = tabs.firstIndex(of: tab) else { return nil }
        tabs.remove(at: index)
        if selection == tab {
            selection = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)]
        }
        let destination = selection
        if tabs.count <= 1 {
            removeAll()
        }
        return destination
    }

    mutating func removeAll() {
        tabs.removeAll()
        selection = nil
    }
}

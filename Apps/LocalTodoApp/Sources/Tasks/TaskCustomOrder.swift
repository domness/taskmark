import Foundation
import LocalTodoDomain

enum TaskListSort: Hashable {
    case automatic(TaskSort)
    case custom
}

struct TaskCustomOrder: Codable {
    var isEnabled = false
    var paths: [String] = []

    func applying(to tasks: [TodoTask]) -> [TodoTask] {
        guard isEnabled else { return tasks }
        let positions = Dictionary(paths.enumerated().map { ($1, $0) }, uniquingKeysWith: min)
        return tasks.enumerated().sorted {
            let lhs = positions[$0.element.path.value] ?? Int.max
            let rhs = positions[$1.element.path.value] ?? Int.max
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
    }
}

struct TaskReorderContext {
    let session: UUID
    let route: WorkspaceRoute
    let grouping: TaskListGrouping
    let visiblePaths: [VaultPath]
    let sectionPaths: [VaultPath]
}

extension WorkspaceModel {
    var currentTaskListSort: TaskListSort {
        isCustomTaskOrder ? .custom : .automatic(currentTaskSort)
    }

    var isCustomTaskOrder: Bool {
        taskCustomOrders[route.listPreferencesKey]?.isEnabled == true
    }

    func setTaskListSort(_ sort: TaskListSort) {
        switch sort {
        case .custom:
            var order = taskCustomOrders[route.listPreferencesKey] ?? TaskCustomOrder()
            if order.paths.isEmpty {
                order.paths = visibleTasks.map(\.path.value)
            }
            order.isEnabled = true
            taskCustomOrders[route.listPreferencesKey] = order
            saveTaskCustomOrders()
        case let .automatic(sort):
            setTaskSort(sort)
        }
    }

    func disableCustomTaskOrder() {
        taskCustomOrders[route.listPreferencesKey]?.isEnabled = false
        saveTaskCustomOrders()
    }

    func taskReorderContext(for tasks: [TodoTask]) -> TaskReorderContext {
        TaskReorderContext(
            session: vaultSession,
            route: route,
            grouping: currentTaskListDisplayOptions.grouping,
            visiblePaths: visibleTasks.map(\.path),
            sectionPaths: tasks.map(\.path)
        )
    }

    @discardableResult
    func moveTasks(from offsets: IndexSet, to destination: Int, context: TaskReorderContext) -> Bool {
        let paths = context.sectionPaths
        guard isCustomTaskOrder, context.session == vaultSession, context.route == route,
              context.grouping == currentTaskListDisplayOptions.grouping,
              context.visiblePaths == visibleTasks.map(\.path),
              !offsets.isEmpty, offsets.allSatisfy(paths.indices.contains),
              (0 ... paths.count).contains(destination), Set(paths).count == paths.count,
              paths == reorderSection(containing: paths.first) else { return false }
        let moved = offsets.map { paths[$0] }
        var remaining = paths.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        remaining.insert(contentsOf: moved, at: destination - offsets.filter { $0 < destination }.count)
        guard remaining != paths else { return false }
        var order = taskCustomOrders[route.listPreferencesKey] ?? TaskCustomOrder(isEnabled: true)
        let known = Set(order.paths)
        order.paths += context.visiblePaths.map(\.value).filter { !known.contains($0) }
        let section = Set(paths.map(\.value))
        var replacements = remaining.map(\.value).makeIterator()
        order.paths = order.paths.map { section.contains($0) ? replacements.next() ?? $0 : $0 }
        taskCustomOrders[route.listPreferencesKey] = order
        saveTaskCustomOrders()
        return true
    }

    private func reorderSection(containing path: VaultPath?) -> [VaultPath] {
        let tasks = visibleTasks
        guard let task = tasks.first(where: { $0.path == path }) else { return [] }
        return tasks.filter {
            switch currentTaskListDisplayOptions.grouping {
            case .none: true
            case .project: $0.project == task.project
            case .area: $0.area == task.area
            }
        }.map(\.path)
    }

    private func saveTaskCustomOrders() {
        queuePreferenceState("custom_order", value: taskCustomOrders)
    }
}

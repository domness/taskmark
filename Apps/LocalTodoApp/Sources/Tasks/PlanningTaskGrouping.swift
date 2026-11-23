import LocalTodoDomain

struct PlanningTaskGroup {
    let date: CalendarDate?
    let tasks: [TodoTask]
}

enum PlanningTaskGrouping {
    static func date(for task: TodoTask, route: WorkspaceRoute, today: CalendarDate?) -> CalendarDate? {
        [task.scheduled, task.deadline].compactMap(\.self).filter { date in
            guard route == .upcoming, let today else { return true }
            return date > today
        }.min()
    }

    /// Preserve the chosen sort (including Custom) within each day.
    static func groups(_ tasks: [TodoTask], route: WorkspaceRoute, today: CalendarDate?) -> [PlanningTaskGroup] {
        let grouped = Dictionary(grouping: tasks) { date(for: $0, route: route, today: today) }
        var sections = grouped.keys.compactMap(\.self).sorted().map { day in
            PlanningTaskGroup(date: day, tasks: grouped[day] ?? [])
        }
        if let undated = grouped[nil] {
            sections.append(PlanningTaskGroup(date: nil, tasks: undated))
        }
        return sections
    }
}

extension WorkspaceRoute {
    var usesPlanningDateSections: Bool {
        self == .next || self == .upcoming
    }
}

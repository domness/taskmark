import LocalTodoDomain

/// Explicit file-format fields keep Swift's enum representation out of the vault contract.
struct SavedFilterFields: Codable {
    var name: String
    var view: TaskView?
    var text: String?
    var project: String?
    var area: String?
    var statuses: [TaskStatus]?
    var priorities: [TaskPriority]?
    var includesNoPriority: Bool?
    var tags: [String]?
    var scheduledFrom: String?
    var scheduledThrough: String?
    var deadlineFrom: String?
    var deadlineThrough: String?
    var includeCompleted: Bool?
    var sort: TaskSort?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, view, text, project, area, statuses, priorities, tags, sort
        case includesNoPriority = "includes_no_priority"
        case scheduledFrom = "scheduled_from"
        case scheduledThrough = "scheduled_through"
        case deadlineFrom = "deadline_from"
        case deadlineThrough = "deadline_through"
        case includeCompleted = "include_completed"
    }

    init(_ filter: SavedTaskFilter) {
        let query = filter.query
        name = filter.name
        view = TaskView(scope: query.scope)
        text = query.text.isEmpty ? nil : query.text
        project = query.filters.project?.value
        area = query.filters.area?.value
        statuses = query.filters.statuses.sorted { $0.rawValue < $1.rawValue }
        priorities = query.filters.priorities.sorted { $0.rawValue < $1.rawValue }
        includesNoPriority = query.filters.includesNoPriority
        tags = query.filters.tags.sorted()
        scheduledFrom = query.filters.scheduled.start?.description
        scheduledThrough = query.filters.scheduled.end?.description
        deadlineFrom = query.filters.deadline.start?.description
        deadlineThrough = query.filters.deadline.end?.description
        includeCompleted = query.includeCompleted
        sort = query.sort
    }

    func filter() throws -> SavedTaskFilter {
        var filters = TaskFilters()
        filters.project = try project.map(VaultPath.init)
        filters.area = try area.map(VaultPath.init)
        filters.statuses = Set(statuses ?? [])
        filters.priorities = Set(priorities ?? [])
        filters.includesNoPriority = includesNoPriority ?? false
        filters.tags = Set(tags ?? [])
        filters.scheduled = try DateRange(
            start: scheduledFrom.map(CalendarDate.init),
            end: scheduledThrough.map(CalendarDate.init)
        )
        filters.deadline = try DateRange(
            start: deadlineFrom.map(CalendarDate.init),
            end: deadlineThrough.map(CalendarDate.init)
        )
        return try SavedTaskFilter(name: name, query: TaskQuery(
            scope: (view ?? .all).scope, text: text ?? "", filters: filters,
            includeCompleted: includeCompleted ?? false, sort: sort ?? .path
        ))
    }
}

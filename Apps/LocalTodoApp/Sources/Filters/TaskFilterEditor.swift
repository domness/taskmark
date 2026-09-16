import Foundation
import LocalTodoDomain

struct TaskFilterEditor: Equatable {
    var view: TaskView = .all
    var text = ""
    var project = ""
    var area = ""
    var statuses = Set<TaskStatus>()
    var priorities = Set<TaskPriority>()
    var includesNoPriority = false
    var tags = ""
    var scheduledFrom = ""
    var scheduledThrough = ""
    var deadlineFrom = ""
    var deadlineThrough = ""
    var includeCompleted = false
    var sort: TaskSort = .priority

    init(query: TaskQuery = TaskQuery(sort: .priority)) {
        view = TaskView(scope: query.scope) ?? .all
        text = query.text
        project = query.filters.project?.value ?? ""
        area = query.filters.area?.value ?? ""
        statuses = query.filters.statuses
        priorities = query.filters.priorities
        includesNoPriority = query.filters.includesNoPriority
        tags = query.filters.tags.sorted().joined(separator: ", ")
        scheduledFrom = query.filters.scheduled.start?.description ?? ""
        scheduledThrough = query.filters.scheduled.end?.description ?? ""
        deadlineFrom = query.filters.deadline.start?.description ?? ""
        deadlineThrough = query.filters.deadline.end?.description ?? ""
        includeCompleted = query.includeCompleted
        sort = query.sort
    }

    func query() throws -> TaskQuery {
        var filters = TaskFilters()
        filters.project = try project.isEmpty ? nil : VaultPath(project)
        filters.area = try area.isEmpty ? nil : VaultPath(area)
        filters.statuses = statuses
        filters.priorities = priorities
        filters.includesNoPriority = includesNoPriority
        filters.tags = Set(tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        filters.scheduled = try DateRange(start: date(scheduledFrom), end: date(scheduledThrough))
        filters.deadline = try DateRange(start: date(deadlineFrom), end: date(deadlineThrough))
        let query = TaskQuery(
            scope: view.scope,
            text: text,
            filters: filters,
            includeCompleted: includeCompleted,
            sort: sort
        )
        return try SavedTaskFilter(name: "Working filter", query: query).query
    }

    var validationMessage: String? {
        do { _ = try query(); return nil } catch {
            return "Use YYYY-MM-DD dates with each start on or before its end, valid paths, and tags without #."
        }
    }

    private func date(_ text: String) throws -> CalendarDate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return try trimmed.isEmpty ? nil : CalendarDate(trimmed)
    }
}

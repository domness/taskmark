import ArgumentParser
import LocalTodoDomain

struct TaskQueryOptions: ParsableArguments {
    @Option(help: "View: inbox, next, or today.")
    var view: String?

    @Option(help: "Status filter. Repeat for multiple statuses.")
    var status: [String] = []

    @Flag(help: "Include completed and canceled tasks.")
    var all = false

    @Option(help: "Project path filter.")
    var project: String?

    @Option(help: "Area path filter.")
    var area: String?

    @Option(help: "Required tag. Repeat for multiple tags.")
    var tag: [String] = []

    @Option(help: "Priority filter. Repeat for multiple priorities.")
    var priority: [String] = []

    @Option(name: .customLong("scheduled-on")) var scheduledOn: String?
    @Option(name: .customLong("scheduled-from")) var scheduledFrom: String?
    @Option(name: .customLong("scheduled-through")) var scheduledThrough: String?
    @Option(name: .customLong("deadline-on")) var deadlineOn: String?
    @Option(name: .customLong("deadline-from")) var deadlineFrom: String?
    @Option(name: .customLong("deadline-through")) var deadlineThrough: String?

    func query(text: String = "") throws -> TaskQuery {
        var filters = TaskFilters()
        filters.statuses = try Set(status.map(CLIParsing.taskStatus))
        let priorityValues = priority.filter { $0 != "none" }
        filters.priorities = try Set(priorityValues.compactMap(CLIParsing.priority))
        filters.includesNoPriority = priority.contains("none")
        filters.project = try project.map(CLIParsing.path)
        filters.area = try area.map(CLIParsing.path)
        filters.tags = Set(tag)
        filters.scheduled = try dateRange(on: scheduledOn, from: scheduledFrom, through: scheduledThrough)
        filters.deadline = try dateRange(on: deadlineOn, from: deadlineFrom, through: deadlineThrough)

        return try TaskQuery(
            scope: scope(),
            text: text,
            filters: filters,
            includeCompleted: all
        )
    }

    private func scope() throws -> TaskScope {
        switch view {
        case nil: .all
        case "inbox": .inbox
        case "next": .next
        case "today": .today
        case let value?: throw CLIError.message("Invalid view: \(value)")
        }
    }

    private func dateRange(on: String?, from: String?, through: String?) throws -> DateRange {
        if let on {
            guard from == nil, through == nil, let date = try CLIParsing.date(on) else {
                throw CLIError.message("A date cannot combine --on with --from or --through")
            }
            return DateRange(start: date, end: date)
        }
        return try DateRange(start: CLIParsing.date(from), end: CLIParsing.date(through))
    }
}

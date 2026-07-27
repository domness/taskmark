public struct TaskFilters: Equatable, Sendable {
    public var statuses: Set<TaskStatus> = []
    public var priorities: Set<TaskPriority> = []
    public var includesNoPriority = false
    public var project: VaultPath?
    public var area: VaultPath?
    public var tags: Set<String> = []
    public var scheduled = DateRange()
    public var deadline = DateRange()

    public init() {}

    func matches(_ task: TodoTask) -> Bool {
        if !statuses.isEmpty, !statuses.contains(task.status) {
            return false
        }
        if !priorities.isEmpty || includesNoPriority {
            let matchesPriority = task.priority.map(priorities.contains) ?? includesNoPriority
            if !matchesPriority {
                return false
            }
        }
        if let project, task.project != project {
            return false
        }
        if let area, task.area != area {
            return false
        }
        if !tags.isSubset(of: Set(task.tags)) {
            return false
        }
        if scheduled.start != nil || scheduled.end != nil, !scheduled.contains(task.scheduled) {
            return false
        }
        if deadline.start != nil || deadline.end != nil, !deadline.contains(task.deadline) {
            return false
        }
        return true
    }
}

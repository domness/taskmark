import LocalTodoDomain

struct TaskOverdueState: Equatable {
    let scheduled: Bool
    let deadline: Bool

    init(task: TodoTask, today: CalendarDate?) {
        guard !task.status.isComplete, let today else {
            scheduled = false
            deadline = false
            return
        }
        scheduled = task.scheduled.map { $0 < today } ?? false
        deadline = task.deadline.map { $0 < today } ?? false
    }

    var isOverdue: Bool {
        scheduled || deadline
    }

    var explanation: String {
        switch (scheduled, deadline) {
        case (true, true): "Scheduled date and deadline have passed"
        case (true, false): "Scheduled date has passed"
        case (false, true): "Deadline has passed"
        case (false, false): ""
        }
    }
}

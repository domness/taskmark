import Foundation

public extension TaskTransition {
    static func duplicate(_ source: TodoTask, at path: VaultPath, now: Date) throws -> TodoTask {
        try TodoTask(
            path: path, title: source.title + " (Copy)",
            status: source.status.isComplete ? .inbox : source.status,
            priority: source.priority, scheduled: source.scheduled, deadline: source.deadline,
            project: source.project, area: source.area, tags: source.tags,
            recurrence: source.recurrence, resetChecklistOnRepeat: source.resetChecklistOnRepeat,
            body: source.body, createdAt: now, updatedAt: now, completedAt: nil
        )
    }
}

import LocalTodoDomain
import LocalTodoMarkdown

enum TaskCommandSupport {
    static func record(at path: VaultPath, in snapshot: VaultSnapshot) throws -> VaultRecord<TodoTask> {
        guard let record = snapshot.tasks[path] else {
            throw CLIError.message("Task not found: \(path.value)")
        }
        return record
    }

    static func validateReferences(_ task: TodoTask, in snapshot: VaultSnapshot) throws {
        if let project = task.project, snapshot.projects[project] == nil {
            throw CLIError.message("Project not found: \(project.value)")
        }
        if let area = task.area, snapshot.areas[area] == nil {
            throw CLIError.message("Area not found: \(area.value)")
        }
    }
}

import LocalTodoDomain

extension LocalTodoEntity {
    func moved(to path: VaultPath) throws -> Self {
        switch self {
        case let .task(task):
            try .task(moved(task, to: path))
        case let .project(project):
            try .project(moved(project, to: path))
        case let .area(area):
            try .area(moved(area, to: path))
        }
    }

    private func moved(_ task: TodoTask, to path: VaultPath) throws -> TodoTask {
        try TodoTask(
            path: path,
            title: task.title,
            status: task.status,
            priority: task.priority,
            scheduled: task.scheduled,
            deadline: task.deadline,
            project: task.project,
            area: task.area,
            tags: task.tags,
            recurrence: task.recurrence,
            resetChecklistOnRepeat: task.resetChecklistOnRepeat,
            body: task.body,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            completedAt: task.completedAt
        )
    }

    private func moved(_ project: Project, to path: VaultPath) throws -> Project {
        try Project(
            path: path,
            title: project.title,
            status: project.status,
            area: project.area,
            tags: project.tags,
            body: project.body,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            completedAt: project.completedAt
        )
    }

    private func moved(_ area: Area, to path: VaultPath) throws -> Area {
        try Area(
            path: path,
            title: area.title,
            status: area.status,
            tags: area.tags,
            body: area.body,
            createdAt: area.createdAt,
            updatedAt: area.updatedAt
        )
    }
}

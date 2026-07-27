import LocalTodoDomain

public enum LocalTodoEntity: Equatable, Sendable {
    case task(TodoTask)
    case project(Project)
    case area(Area)

    public var path: VaultPath {
        switch self {
        case let .task(task): task.path
        case let .project(project): project.path
        case let .area(area): area.path
        }
    }
}

import Foundation

public struct ProjectPatch: Equatable, Sendable {
    public var title: FieldUpdate<String> = .unchanged
    public var status: FieldUpdate<ProjectStatus> = .unchanged
    public var area: FieldUpdate<VaultPath?> = .unchanged
    public var tags: FieldUpdate<[String]> = .unchanged
    public var body: FieldUpdate<String> = .unchanged

    public init() {}

    public func applying(to project: Project, now: Date) throws -> Project {
        let nextStatus = status.resolve(project.status)
        let nextCompletedAt: Date? = if nextStatus == .done {
            project.completedAt ?? now
        } else {
            nil
        }

        return try Project(
            path: project.path,
            title: title.resolve(project.title),
            status: nextStatus,
            area: area.resolve(project.area),
            tags: tags.resolve(project.tags),
            body: body.resolve(project.body),
            createdAt: project.createdAt,
            updatedAt: now,
            completedAt: nextCompletedAt
        )
    }
}

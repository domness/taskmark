import Foundation

public enum ProjectTransition {
    public static func complete(_ project: Project, now: Date) throws -> Project {
        guard project.status != .canceled else {
            throw DomainValidationError.invalidCompletionState
        }
        var patch = ProjectPatch()
        patch.status = .set(.done)
        return try patch.applying(to: project, now: now)
    }

    public static func reopen(_ project: Project, status: ProjectStatus = .active, now: Date) throws -> Project {
        guard
            project.status == .done || project.status == .canceled,
            status == .active || status == .someday
        else {
            throw DomainValidationError.invalidCompletionState
        }
        var patch = ProjectPatch()
        patch.status = .set(status)
        return try patch.applying(to: project, now: now)
    }
}

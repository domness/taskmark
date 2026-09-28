import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

public extension WorkspaceSession {
    @discardableResult
    func createCollection(kind: WorkspaceCollectionKind, title: String) async throws -> VaultPath {
        guard let store, let snapshot else { throw WorkspaceSessionError.noVault }
        let path = try nextCollectionPath(kind: kind, title: title, snapshot: snapshot)
        let now = clock()
        let entity: LocalTodoEntity = switch kind {
        case .project:
            try .project(Project(path: path, title: title, status: .active, createdAt: now, updatedAt: now))
        case .area:
            try .area(Area(path: path, title: title, status: .active, createdAt: now, updatedAt: now))
        }
        isSaving = true
        defer { isSaving = false }
        _ = try await store.create(entity)
        self.snapshot = try await store.snapshot()
        return path
    }

    func updateProject(at path: VaultPath, patch: ProjectPatch) async throws {
        try requireAvailable(path)
        guard let store, let record = snapshot?.projects[path] else {
            throw WorkspaceSessionError.collectionUnavailable(path)
        }
        let updated = try patch.applying(to: record.value, now: clock())
        isSaving = true
        defer { isSaving = false }
        _ = try await store.update(.project(updated), expectedRevision: record.revision)
        snapshot = try await store.snapshot()
    }

    func updateArea(at path: VaultPath, patch: AreaPatch) async throws {
        try requireAvailable(path)
        guard let store, let record = snapshot?.areas[path] else {
            throw WorkspaceSessionError.collectionUnavailable(path)
        }
        let updated = try patch.applying(to: record.value, now: clock())
        isSaving = true
        defer { isSaving = false }
        _ = try await store.update(.area(updated), expectedRevision: record.revision)
        snapshot = try await store.snapshot()
    }

    func deleteCollection(at path: VaultPath) async throws {
        try requireAvailable(path)
        guard let store else { throw WorkspaceSessionError.noVault }
        let revision = snapshot?.projects[path]?.revision ?? snapshot?.areas[path]?.revision
        guard let revision else { throw WorkspaceSessionError.collectionUnavailable(path) }
        isSaving = true
        defer { isSaving = false }
        _ = try await store.delete(at: path, expectedRevision: revision)
        snapshot = try await store.snapshot()
    }

    private func nextCollectionPath(
        kind: WorkspaceCollectionKind, title: String, snapshot: VaultSnapshot
    ) throws -> VaultPath {
        let slug = title.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let directory = kind == .project ? "Projects" : "Areas"
        let base = slug.isEmpty ? kind.rawValue : slug
        var suffix = 1
        while true {
            let name = suffix == 1 ? base : "\(base)-\(suffix)"
            let path = try VaultPath("\(directory)/\(name).md")
            if snapshot.tasks[path] == nil, snapshot.projects[path] == nil, snapshot.areas[path] == nil {
                return path
            }
            suffix += 1
        }
    }
}

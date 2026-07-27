import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func createCollection(kind: NewEntityKind, path: String, title: String) async {
        guard let store else { return }
        let session = vaultSession
        do {
            let entityPath = try VaultPath(path)
            let entity = try collectionEntity(kind: kind, path: entityPath, title: title, now: Date())
            guard beginMutation(at: entityPath) else { return }
            let record = try await store.create(entity)
            endMutation(at: entityPath)
            guard session == vaultSession else { return }
            merge(record)
            registerHistory(
                replacingWith: nil,
                at: entityPath,
                actionName: kind == .project ? "Create Project" : "Create Area"
            )
            newEntityKind = nil
            await refresh()
        } catch {
            if let entityPath = try? VaultPath(path) {
                endMutation(at: entityPath)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func collectionEntity(
        kind: NewEntityKind,
        path: VaultPath,
        title: String,
        now: Date
    ) throws -> LocalTodoEntity {
        switch kind {
        case .project:
            try .project(Project(path: path, title: title, status: .active, createdAt: now, updatedAt: now))
        case .area:
            try .area(Area(path: path, title: title, status: .active, createdAt: now, updatedAt: now))
        }
    }
}

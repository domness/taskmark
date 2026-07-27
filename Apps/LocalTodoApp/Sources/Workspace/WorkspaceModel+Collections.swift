import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func createCollection(kind: NewEntityKind, path: String, title: String) async {
        guard let store else { return }
        do {
            let entityPath = try VaultPath(path)
            let now = Date()
            let entity: LocalTodoEntity = switch kind {
            case .project:
                try .project(Project(
                    path: entityPath,
                    title: title,
                    status: .active,
                    createdAt: now,
                    updatedAt: now
                ))
            case .area:
                try .area(Area(
                    path: entityPath,
                    title: title,
                    status: .active,
                    createdAt: now,
                    updatedAt: now
                ))
            }
            _ = try await store.create(entity)
            newEntityKind = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

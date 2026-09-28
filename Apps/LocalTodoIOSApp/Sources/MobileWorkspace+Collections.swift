import LocalTodoDomain
import LocalTodoWorkspace

extension MobileWorkspace {
    func createCollection(kind: WorkspaceCollectionKind, title: String) async -> VaultPath? {
        do {
            return try await session.createCollection(kind: kind, title: title)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateProject(at path: VaultPath, patch: ProjectPatch) async -> Bool {
        do {
            try await session.updateProject(at: path, patch: patch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateArea(at path: VaultPath, patch: AreaPatch) async -> Bool {
        do {
            try await session.updateArea(at: path, patch: patch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteCollection(at path: VaultPath) async -> Bool {
        do {
            try await session.deleteCollection(at: path)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

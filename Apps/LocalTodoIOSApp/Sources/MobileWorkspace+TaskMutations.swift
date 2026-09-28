import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import LocalTodoWorkspace

extension MobileWorkspace {
    func updateTitle(for path: VaultPath, title: String) async {
        do {
            var patch = TaskPatch()
            patch.title = .set(title)
            try await session.updateTask(at: path, patch: patch)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete(_ path: VaultPath) async {
        do {
            try await session.toggleCompletion(at: path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func capture(title: String, route: WorkspaceRoute, patch: TaskPatch = TaskPatch()) async -> Bool {
        do {
            _ = try await session.capture(title: title, route: route, patch: patch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateTask(at path: VaultPath, patch: TaskPatch) async -> Bool {
        do {
            try await session.updateTask(at: path, patch: patch)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTask(at path: VaultPath) async -> Bool {
        do {
            try await session.deleteTask(at: path)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func duplicateTask(at path: VaultPath) async -> VaultPath? {
        do {
            return try await session.duplicateTask(at: path)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func setPreferences(_ changes: [String: ConfigurationValue]) async -> Bool {
        do {
            try await session.setPreferences(changes)
            await refreshAppearance()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setTimezone(_ identifier: String?) async -> Bool {
        do {
            try await session.setTimezone(identifier)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

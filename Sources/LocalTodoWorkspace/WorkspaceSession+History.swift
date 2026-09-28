import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

enum PersistedHistoryState: Sendable {
    case absent
    case content(Data)
}

struct PersistedHistoryAction: Sendable {
    let path: VaultPath
    let before: PersistedHistoryState
    let after: PersistedHistoryState
    let actionName: String
}

public extension WorkspaceSession {
    func undo() async throws {
        guard let action = undoHistory.last, let store else { return }
        try await applyHistory(action.before, for: action.path, store: store)
        undoHistory.removeLast()
        redoHistory.append(action)
        updateHistoryAvailability()
    }

    func redo() async throws {
        guard let action = redoHistory.last, let store else { return }
        try await applyHistory(action.after, for: action.path, store: store)
        redoHistory.removeLast()
        undoHistory.append(action)
        updateHistoryAvailability()
    }

    func clearHistory() {
        undoHistory.removeAll()
        redoHistory.removeAll()
        updateHistoryAvailability()
    }

    internal func registerHistory(_ action: PersistedHistoryAction) {
        undoHistory.append(action)
        redoHistory.removeAll()
        updateHistoryAvailability()
    }

    internal func recordCreatedEntity(at path: VaultPath, actionName: String, store: VaultStore) async throws {
        guard let revision = entityRevision(at: path) else { return }
        let content = try await store.entityContent(at: path, expectedRevision: revision)
        registerHistory(.init(path: path, before: .absent, after: .content(content), actionName: actionName))
    }

    private func applyHistory(
        _ state: PersistedHistoryState,
        for path: VaultPath,
        store: VaultStore
    ) async throws {
        isSaving = true
        defer { isSaving = false }
        do {
            switch (state, entityRevision(at: path)) {
            case let (.absent, revision?):
                _ = try await store.delete(at: path, expectedRevision: revision)
            case (.absent, nil):
                break
            case let (.content(content), revision?):
                _ = try await store.replaceEntityContent(content, at: path, expectedRevision: revision)
            case let (.content(content), nil):
                _ = try await store.restoreEntityContent(content, at: path)
            }
            snapshot = try await store.snapshot()
        } catch {
            clearHistory()
            snapshot = try? await store.snapshot()
            throw error
        }
    }

    private func entityRevision(at path: VaultPath) -> FileRevision? {
        snapshot?.tasks[path]?.revision ?? snapshot?.projects[path]?.revision ?? snapshot?.areas[path]?.revision
    }

    private func updateHistoryAvailability() {
        canUndo = !undoHistory.isEmpty
        canRedo = !redoHistory.isEmpty
    }
}

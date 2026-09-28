import Foundation
import LocalTodoMarkdown

public extension WorkspaceSession {
    func resolveProviderConflict(
        _ conflict: VaultProviderConflict,
        choosing content: Data
    ) async throws {
        guard let store else { throw WorkspaceSessionError.noVault }
        isSaving = true
        defer { isSaving = false }
        try await store.resolveProviderConflict(
            at: conflict.path,
            choosing: content,
            expectedCurrentRevision: conflict.currentRevision,
            expectedVersionIdentifiers: Set(conflict.alternatives.map(\.id))
        )
        snapshot = try await store.snapshot()
    }
}

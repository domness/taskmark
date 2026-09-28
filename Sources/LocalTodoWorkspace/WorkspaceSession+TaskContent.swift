import Foundation
import LocalTodoDomain

public extension WorkspaceSession {
    func taskMarkdown(at path: VaultPath) async throws -> String {
        try requireAvailable(path)
        guard let store, let record = snapshot?.tasks[path] else {
            throw WorkspaceSessionError.taskUnavailable(path)
        }
        let data = try await store.taskContent(at: path, expectedRevision: record.revision)
        guard let source = String(data: data, encoding: .utf8) else {
            throw WorkspaceSessionError.taskUnavailable(path)
        }
        return source
    }
}

import Foundation
import LocalTodoDomain

public extension VaultStore {
    /// Captures exact Markdown for clipboard export and reversible deletion.
    func taskContent(at path: VaultPath, expectedRevision: FileRevision) throws -> Data {
        let data = try entityContent(at: path, expectedRevision: expectedRevision)
        guard case .task = try EntityDocumentCodec.decode(parseDocument(data, at: path), at: path) else {
            throw VaultStoreError.wrongEntityType(path)
        }
        return data
    }

    /// Exclusive publication never replaces an occupied path, including malformed files.
    func restoreTaskContent(_ data: Data, at path: VaultPath) throws -> VaultRecord<LocalTodoEntity> {
        guard case .task = try EntityDocumentCodec.decode(parseDocument(data, at: path), at: path) else {
            throw VaultStoreError.wrongEntityType(path)
        }
        return try restoreEntityContent(data, at: path)
    }

    func entityContent(at path: VaultPath, expectedRevision: FileRevision) throws -> Data {
        try validateEntityPath(path)
        let data = try performIO { try fileSystem.read(at: fileURL(for: path)) }
        guard FileRevision(data: data) == expectedRevision else { throw VaultStoreError.conflict(path) }
        _ = try EntityDocumentCodec.decode(parseDocument(data, at: path), at: path)
        return data
    }

    /// Restores exact bytes for any entity, without replacing an occupied path.
    func restoreEntityContent(_ data: Data, at path: VaultPath) throws -> VaultRecord<LocalTodoEntity> {
        try validateEntityPath(path)
        let entity = try EntityDocumentCodec.decode(parseDocument(data, at: path), at: path)
        let url = fileURL(for: path)
        guard !fileSystem.exists(at: url) else { throw VaultStoreError.destinationExists(path) }
        try performIO { try fileSystem.createDirectory(at: url.deletingLastPathComponent()) }
        try performIO {
            try fileSystem.coordinateWriting(at: url, intent: .replacing) { coordinatedURL in
                guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else {
                    throw VaultStoreError.conflict(path)
                }
                try validateEntityPath(path)
                try fileSystem.writeExclusively(data, to: coordinatedURL)
            }
        }
        return VaultRecord(value: entity, revision: FileRevision(data: data))
    }

    func duplicateTask(
        at path: VaultPath, expectedRevision: FileRevision, now: Date
    ) throws -> VaultRecord<LocalTodoEntity> {
        let data = try taskContent(at: path, expectedRevision: expectedRevision)
        let document = try parseDocument(data, at: path)
        guard case let .task(source) = try EntityDocumentCodec.decode(document, at: path) else {
            throw VaultStoreError.wrongEntityType(path)
        }
        let base = String(path.value.dropLast(3)) + "-copy"
        var suffix = 1
        while true {
            let destination = try VaultPath(base + (suffix == 1 ? "" : "-\(suffix)") + ".md")
            let copy = try TaskTransition.duplicate(source, at: destination, now: now)
            let content = try renderedData(EntityDocumentCodec.encode(.task(copy), preserving: document))
            do {
                return try restoreTaskContent(content, at: destination)
            } catch {
                guard fileSystem.exists(at: fileURL(for: destination)) else { throw error }
                suffix += 1
            }
        }
    }
}

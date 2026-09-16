import Foundation
import LocalTodoDomain

extension VaultStore {
    public func update(
        _ entity: LocalTodoEntity,
        expectedRevision: FileRevision
    ) throws -> VaultRecord<LocalTodoEntity> {
        try validateEntityPath(entity.path)
        var result: VaultRecord<LocalTodoEntity>?
        let url = fileURL(for: entity.path)
        try performIO {
            try fileSystem.coordinateWriting(at: url, intent: .replacing) { coordinatedURL in
                guard coordinatedURL.standardizedFileURL.path == url.standardizedFileURL.path else {
                    throw VaultStoreError.conflict(entity.path)
                }
                try validateEntityPath(entity.path)
                result = try updateCoordinated(
                    entity,
                    at: coordinatedURL,
                    expectedRevision: expectedRevision
                )
            }
        }
        guard let result else {
            throw VaultStoreError.inputOutput("Coordinated update did not run")
        }
        return result
    }

    public func delete(at path: VaultPath, expectedRevision: FileRevision) throws -> LocalTodoEntity {
        try validateEntityPath(path)
        var result: LocalTodoEntity?
        let url = fileURL(for: path)
        try performIO {
            try fileSystem.coordinateWriting(at: url, intent: .deleting) { coordinatedURL in
                guard coordinatedURL.standardizedFileURL.path == url.standardizedFileURL.path else {
                    throw VaultStoreError.conflict(path)
                }
                try validateEntityPath(path)
                result = try deleteCoordinated(
                    at: path,
                    coordinatedURL: coordinatedURL,
                    expectedRevision: expectedRevision
                )
            }
        }
        guard let result else {
            throw VaultStoreError.inputOutput("Coordinated delete did not run")
        }
        return result
    }

    private func updateCoordinated(
        _ entity: LocalTodoEntity,
        at url: URL,
        expectedRevision: FileRevision
    ) throws -> VaultRecord<LocalTodoEntity> {
        guard fileSystem.exists(at: url) else {
            throw VaultStoreError.notFound(entity.path)
        }
        let currentData = try performIO { try fileSystem.read(at: url) }
        guard FileRevision(data: currentData) == expectedRevision else {
            throw VaultStoreError.conflict(entity.path)
        }
        let currentDocument = try parseDocument(currentData, at: entity.path)
        let currentEntity = try EntityDocumentCodec.decode(currentDocument, at: entity.path)
        guard sameKind(currentEntity, entity) else {
            throw VaultStoreError.wrongEntityType(entity.path)
        }
        let updatedDocument = try EntityDocumentCodec.encode(entity, preserving: currentDocument)
        let updatedData = try renderedData(updatedDocument)
        try performIO { try fileSystem.writeAtomically(updatedData, to: url) }
        return VaultRecord(value: entity, revision: FileRevision(data: updatedData))
    }

    private func deleteCoordinated(
        at path: VaultPath,
        coordinatedURL url: URL,
        expectedRevision: FileRevision
    ) throws -> LocalTodoEntity {
        guard fileSystem.exists(at: url) else {
            throw VaultStoreError.notFound(path)
        }
        let data = try performIO { try fileSystem.read(at: url) }
        guard FileRevision(data: data) == expectedRevision else {
            throw VaultStoreError.conflict(path)
        }
        let document = try parseDocument(data, at: path)
        let entity = try EntityDocumentCodec.decode(document, at: path)
        try ensureNotReferenced(entity)
        try performIO { try fileSystem.removeFile(at: url) }
        return entity
    }

    private func ensureNotReferenced(_ entity: LocalTodoEntity) throws {
        let snapshot = try snapshot()
        let isReferenced = switch entity {
        case .task:
            false
        case let .project(project):
            snapshot.tasks.values.contains { $0.value.project == project.path }
        case let .area(area):
            snapshot.tasks.values.contains { $0.value.area == area.path }
                || snapshot.projects.values.contains { $0.value.area == area.path }
        }
        if isReferenced {
            throw VaultStoreError.invalidVault("Cannot delete referenced entity at \(entity.path.value)")
        }
    }
}

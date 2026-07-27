import Foundation
import LocalTodoDomain

public actor VaultStore {
    public let root: URL

    let fileSystem: any VaultFileSystem
    private var generation: UInt64 = 0

    public init(root: URL, fileSystem: any VaultFileSystem = FoundationVaultFileSystem()) {
        self.root = root.standardizedFileURL
        self.fileSystem = fileSystem
    }

    public func snapshot() throws -> VaultSnapshot {
        generation += 1
        return try VaultScanner(root: root, fileSystem: fileSystem).scan(generation: generation)
    }

    public func fileExists(at path: VaultPath) -> Bool {
        fileSystem.exists(at: fileURL(for: path))
    }

    public func create(_ entity: LocalTodoEntity) throws -> VaultRecord<LocalTodoEntity> {
        let url = fileURL(for: entity.path)
        guard !fileSystem.exists(at: url) else {
            throw VaultStoreError.destinationExists(entity.path)
        }
        let document = try EntityDocumentCodec.encode(entity)
        let data = try renderedData(document)
        let missingDirectories = missingDirectories(endingAt: url.deletingLastPathComponent())
        do {
            if !missingDirectories.isEmpty {
                try performIO { try fileSystem.createDirectory(at: url.deletingLastPathComponent()) }
            }
            try performIO { try fileSystem.writeExclusively(data, to: url) }
        } catch {
            for directory in missingDirectories {
                try? fileSystem.removeEmptyDirectory(at: directory)
            }
            if fileSystem.exists(at: url) {
                throw VaultStoreError.destinationExists(entity.path)
            }
            throw error
        }
        return VaultRecord(value: entity, revision: FileRevision(data: data))
    }

    public func move(from source: VaultPath, to destination: VaultPath, now: Date) throws -> VaultSnapshot {
        let sourceURL = fileURL(for: source)
        let destinationURL = fileURL(for: destination)
        guard fileSystem.exists(at: sourceURL) else {
            throw VaultStoreError.notFound(source)
        }
        guard !fileSystem.exists(at: destinationURL) else {
            throw VaultStoreError.destinationExists(destination)
        }
        guard fileSystem.exists(at: destinationURL.deletingLastPathComponent()) else {
            throw VaultStoreError.invalidVault("Destination parent directory does not exist")
        }

        let currentSnapshot = try snapshot()
        let sourceData = try performIO { try fileSystem.read(at: sourceURL) }
        let sourceDocument = try parseDocument(sourceData, at: source)
        let sourceEntity = try EntityDocumentCodec.decode(sourceDocument, at: source)
        let movedEntity = try sourceEntity.moved(to: destination)
        var writes = try referenceWrites(
            for: sourceEntity,
            destination: destination,
            snapshot: currentSnapshot,
            now: now
        )
        let movedDocument = try EntityDocumentCodec.encode(movedEntity, preserving: sourceDocument)
        writes[destinationURL] = try renderedData(movedDocument)

        try VaultMoveTransaction(fileSystem: fileSystem).apply(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            writes: writes
        )
        return try snapshot()
    }

    private func referenceWrites(
        for source: LocalTodoEntity,
        destination: VaultPath,
        snapshot: VaultSnapshot,
        now: Date
    ) throws -> [URL: Data] {
        var writes = [URL: Data]()
        for record in snapshot.tasks.values {
            var patch = TaskPatch()
            switch source {
            case .project where record.value.project == source.path:
                patch.project = .set(destination)
            case .area where record.value.area == source.path:
                patch.area = .set(destination)
            default:
                continue
            }
            let updated = try patch.applying(to: record.value, now: now)
            writes[fileURL(for: updated.path)] = try updatedData(.task(updated), at: updated.path)
        }
        if case .area = source {
            for record in snapshot.projects.values where record.value.area == source.path {
                var patch = ProjectPatch()
                patch.area = .set(destination)
                let updated = try patch.applying(to: record.value, now: now)
                writes[fileURL(for: updated.path)] = try updatedData(.project(updated), at: updated.path)
            }
        }
        return writes
    }

    private func updatedData(_ entity: LocalTodoEntity, at path: VaultPath) throws -> Data {
        let data = try performIO { try fileSystem.read(at: fileURL(for: path)) }
        let document = try parseDocument(data, at: path)
        return try renderedData(EntityDocumentCodec.encode(entity, preserving: document))
    }

    func parseDocument(_ data: Data, at path: VaultPath) throws -> MarkdownDocument {
        guard let source = String(data: data, encoding: .utf8) else {
            throw VaultStoreError.inputOutput("File is not valid UTF-8: \(path.value)")
        }
        return try MarkdownDocument.parse(source)
    }

    func renderedData(_ document: MarkdownDocument) throws -> Data {
        guard let data = try document.rendered().data(using: .utf8) else {
            throw VaultStoreError.inputOutput("Unable to encode Markdown")
        }
        return data
    }

    func fileURL(for path: VaultPath) -> URL {
        root.appendingPathComponent(path.value)
    }

    private func missingDirectories(endingAt directory: URL) -> [URL] {
        var result = [URL]()
        var current = directory.standardizedFileURL
        while current.path != root.path, !fileSystem.exists(at: current) {
            result.append(current)
            current.deleteLastPathComponent()
        }
        return result
    }

    func sameKind(_ lhs: LocalTodoEntity, _ rhs: LocalTodoEntity) -> Bool {
        switch (lhs, rhs) {
        case (.task, .task), (.project, .project), (.area, .area): true
        default: false
        }
    }

    func performIO<Value>(_ operation: () throws -> Value) throws -> Value {
        do {
            return try operation()
        } catch let error as VaultStoreError {
            throw error
        } catch {
            throw VaultStoreError.inputOutput(error.localizedDescription)
        }
    }
}

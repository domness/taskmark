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
        try validateEntityPath(entity.path)
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

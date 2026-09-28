import Foundation
import LocalTodoDomain

public actor VaultStore {
    public let root: URL

    let fileSystem: any VaultFileSystem
    private var generation: UInt64 = 0
    private var lastSnapshot: VaultSnapshot?

    public init(root: URL, fileSystem: any VaultFileSystem = FoundationVaultFileSystem()) {
        self.root = root.standardizedFileURL
        self.fileSystem = fileSystem
    }

    public func snapshot() throws -> VaultSnapshot {
        generation += 1
        let scanned = try VaultScanner(root: root, fileSystem: fileSystem).scan(generation: generation)
        let snapshot = mergePartialScan(scanned)
        lastSnapshot = snapshot
        let filterIssues = snapshot.scanCompleteness == .complete ? filterDiagnostics(in: snapshot) : []
        return VaultSnapshot(
            generation: snapshot.generation, configuration: snapshot.configuration,
            tasks: snapshot.tasks, projects: snapshot.projects, areas: snapshot.areas,
            diagnostics: snapshot.diagnostics + filterIssues,
            scanCompleteness: snapshot.scanCompleteness,
            availability: snapshot.availability,
            providerConflicts: snapshot.providerConflicts
        )
    }

    private func mergePartialScan(_ scanned: VaultSnapshot) -> VaultSnapshot {
        guard case .partial = scanned.scanCompleteness, let previous = lastSnapshot else { return scanned }
        var tasks = previous.tasks
        var projects = previous.projects
        var areas = previous.areas
        var providerConflicts = previous.providerConflicts
        tasks.merge(scanned.tasks) { _, new in new }
        projects.merge(scanned.projects) { _, new in new }
        areas.merge(scanned.areas) { _, new in new }
        providerConflicts.merge(scanned.providerConflicts) { _, new in new }
        var availability = scanned.availability
        for path in Set(tasks.keys).union(projects.keys).union(areas.keys) where availability[path] == nil {
            availability[path] = .unavailable("Not returned by an incomplete provider scan")
        }
        return VaultSnapshot(
            generation: scanned.generation,
            configuration: scanned.configuration,
            tasks: tasks,
            projects: projects,
            areas: areas,
            diagnostics: scanned.diagnostics,
            scanCompleteness: scanned.scanCompleteness,
            availability: availability,
            providerConflicts: providerConflicts
        )
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
            try performIO {
                try fileSystem.coordinateWriting(at: url, intent: .creating) { coordinatedURL in
                    guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else {
                        throw VaultStoreError.conflict(entity.path)
                    }
                    try fileSystem.writeExclusively(data, to: coordinatedURL)
                }
            }
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
        } catch let error as VaultConfigurationError {
            throw error
        } catch {
            throw VaultStoreError.inputOutput(error.localizedDescription)
        }
    }
}

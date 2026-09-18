import Foundation
import LocalTodoDomain

public struct VaultScanner: Sendable {
    private let root: URL
    private let fileSystem: any VaultFileSystem

    public init(root: URL, fileSystem: any VaultFileSystem = FoundationVaultFileSystem()) {
        self.root = root.standardizedFileURL
        self.fileSystem = fileSystem
    }

    public func scan(generation: UInt64 = 0) throws -> VaultSnapshot {
        let configuration = try loadConfiguration()
        var results = ScanResults()

        for url in try fileSystem.markdownFiles(in: root) {
            scan(url, into: &results)
        }

        results.diagnostics.append(
            contentsOf: referenceDiagnostics(tasks: results.tasks, projects: results.projects, areas: results.areas)
        )
        return VaultSnapshot(
            generation: generation,
            configuration: configuration,
            tasks: results.tasks,
            projects: results.projects,
            areas: results.areas,
            diagnostics: results.diagnostics.sorted(by: diagnosticOrder)
        )
    }

    private func scan(_ url: URL, into results: inout ScanResults) {
        guard let path = try? vaultPath(for: url) else {
            return
        }
        do {
            let data = try fileSystem.read(at: url)
            guard let source = String(data: data, encoding: .utf8) else {
                results.diagnostics.append(diagnostic(
                    .frontmatterMalformed,
                    path: path,
                    message: "File is not valid UTF-8"
                ))
                return
            }
            guard source.hasPrefix("---\n") || source.hasPrefix("---\r\n") else {
                return
            }
            let document = try MarkdownDocument.parse(source)
            let entity = try EntityDocumentCodec.decode(document, at: path)
            results.insert(entity, revision: FileRevision(data: data))
        } catch let error as EntityDocumentError {
            if case .unsupportedEntityType = error {
                return
            }
            results.diagnostics.append(diagnostic(for: error, path: path))
        } catch is MarkdownDocumentError {
            results.diagnostics.append(diagnostic(.frontmatterMalformed, path: path, message: "Malformed frontmatter"))
        } catch {
            results.diagnostics.append(diagnostic(.inputOutput, path: path, message: error.localizedDescription))
        }
    }

    func loadConfiguration() throws -> VaultConfiguration {
        let manifest = root.appendingPathComponent(LocalTodoSchema.manifestPath)
        let paths = [".config", LocalTodoSchema.manifestPath].map { root.appendingPathComponent($0) }
        for url in paths where try fileSystem.isSymbolicLink(at: url) {
            throw VaultStoreError.invalidVault("Vault configuration must not use symbolic links")
        }
        guard fileSystem.exists(at: manifest) else {
            throw VaultStoreError.invalidVault("Missing \(LocalTodoSchema.manifestPath)")
        }
        do {
            let data = try fileSystem.read(at: manifest)
            guard let yaml = String(data: data, encoding: .utf8) else {
                throw VaultStoreError.invalidVault("Manifest is not valid UTF-8")
            }
            let configuration = try VaultConfiguration.decode(yaml: yaml)
            guard configuration.schema == LocalTodoSchema.currentVersion else {
                throw VaultStoreError.unsupportedSchema(configuration.schema)
            }
            if let timezone = configuration.timezone, TimeZone(identifier: timezone) == nil {
                throw VaultStoreError.invalidVault("Invalid timezone: \(timezone)")
            }
            return configuration
        } catch let error as VaultStoreError {
            throw error
        } catch {
            throw VaultStoreError.invalidVault(error.localizedDescription)
        }
    }

    private func vaultPath(for url: URL) throws -> VaultPath {
        let rootPath = root.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else {
            throw DomainValidationError.invalidVaultPath
        }
        return try VaultPath(String(path.dropFirst(rootPath.count + 1)))
    }

    private func diagnostic(for error: EntityDocumentError, path: VaultPath) -> VaultDiagnostic {
        switch error {
        case let .missingField(field):
            diagnostic(.requiredFieldMissing, path: path, field: field, message: "Missing required field: \(field)")
        case let .invalidField(field):
            diagnostic(.fieldInvalid, path: path, field: field, message: "Invalid field: \(field)")
        case let .invalidDomainValue(error):
            diagnostic(.fieldInvalid, path: path, message: "Invalid entity: \(error)")
        case let .unsupportedEntityType(type):
            diagnostic(.entityTypeInvalid, path: path, field: "type", message: "Unsupported entity type: \(type)")
        }
    }

    private func diagnostic(
        _ kind: VaultDiagnostic.Kind,
        path: VaultPath,
        field: String? = nil,
        reference: VaultPath? = nil,
        message: String
    ) -> VaultDiagnostic {
        VaultDiagnostic(severity: .error, kind: kind, message: message, path: path, field: field, reference: reference)
    }

    private func referenceDiagnostics(
        tasks: [VaultPath: VaultRecord<TodoTask>],
        projects: [VaultPath: VaultRecord<Project>],
        areas: [VaultPath: VaultRecord<Area>]
    ) -> [VaultDiagnostic] {
        var diagnostics = [VaultDiagnostic]()
        for (path, record) in tasks {
            if let project = record.value.project, projects[project] == nil {
                diagnostics.append(referenceDiagnostic(
                    path: path,
                    field: "project",
                    reference: project,
                    wrongType: tasks[project] != nil || areas[project] != nil
                ))
            }
            if let area = record.value.area, areas[area] == nil {
                diagnostics.append(referenceDiagnostic(
                    path: path,
                    field: "area",
                    reference: area,
                    wrongType: tasks[area] != nil || projects[area] != nil
                ))
            }
        }
        for (path, record) in projects {
            if let area = record.value.area, areas[area] == nil {
                diagnostics.append(referenceDiagnostic(
                    path: path,
                    field: "area",
                    reference: area,
                    wrongType: tasks[area] != nil || projects[area] != nil
                ))
            }
        }
        return diagnostics
    }

    private func referenceDiagnostic(
        path: VaultPath,
        field: String,
        reference: VaultPath,
        wrongType: Bool
    ) -> VaultDiagnostic {
        let kind: VaultDiagnostic.Kind = wrongType ? .referenceTypeMismatch : .referenceMissing
        let message = wrongType ? "Reference has the wrong entity type" : "Missing reference: \(reference.value)"
        return diagnostic(
            kind,
            path: path,
            field: field,
            reference: reference,
            message: message
        )
    }

    private func diagnosticOrder(_ lhs: VaultDiagnostic, _ rhs: VaultDiagnostic) -> Bool {
        (lhs.path?.value ?? "", lhs.kind.rawValue) < (rhs.path?.value ?? "", rhs.kind.rawValue)
    }
}

private struct ScanResults {
    var tasks = [VaultPath: VaultRecord<TodoTask>]()
    var projects = [VaultPath: VaultRecord<Project>]()
    var areas = [VaultPath: VaultRecord<Area>]()
    var diagnostics = [VaultDiagnostic]()

    mutating func insert(_ entity: LocalTodoEntity, revision: FileRevision) {
        switch entity {
        case let .task(task): tasks[task.path] = VaultRecord(value: task, revision: revision)
        case let .project(project): projects[project.path] = VaultRecord(value: project, revision: revision)
        case let .area(area): areas[area.path] = VaultRecord(value: area, revision: revision)
        }
    }
}

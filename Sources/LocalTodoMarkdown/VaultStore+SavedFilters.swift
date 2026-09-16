import Foundation
import LocalTodoDomain

public struct SavedFilterRecord: Equatable, Sendable {
    public let filters: [SavedTaskFilter]
    public let revision: FileRevision?

    public init(filters: [SavedTaskFilter] = [], revision: FileRevision? = nil) {
        self.filters = filters
        self.revision = revision
    }
}

extension VaultStore {
    public static let savedFiltersPath = ".localtodo/filters.md"

    public func savedFilters() throws -> SavedFilterRecord {
        let url = try savedFilterURL()
        guard fileSystem.exists(at: url) else { return SavedFilterRecord() }
        let data = try performIO { try fileSystem.read(at: url) }
        return try SavedFilterRecord(
            filters: SavedFilterDocumentCodec.decode(filterDocument(data)),
            revision: FileRevision(data: data)
        )
    }

    public func saveFilters(_ filters: [SavedTaskFilter], expectedRevision: FileRevision?) throws -> SavedFilterRecord {
        let url = try savedFilterURL()
        var result: SavedFilterRecord?
        try fileSystem.coordinateWriting(at: url, intent: .replacing) { coordinatedURL in
            guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else { throw SavedFilterError.conflict }
            _ = try savedFilterURL()
            result = try writeFilters(filters, at: coordinatedURL, expectedRevision: expectedRevision)
        }
        guard let result else { throw VaultStoreError.inputOutput("Coordinated filter save did not run") }
        return result
    }

    private func writeFilters(
        _ filters: [SavedTaskFilter], at url: URL, expectedRevision: FileRevision?
    ) throws -> SavedFilterRecord {
        let existingData = try fileSystem.exists(at: url) ? performIO { try fileSystem.read(at: url) } : nil
        guard existingData.map(FileRevision.init(data:)) == expectedRevision else { throw SavedFilterError.conflict }
        let existing = try existingData.map(filterDocument)
        let document = try SavedFilterDocumentCodec.encode(filters, preserving: existing)
        let data = try renderedData(document)
        if existingData == nil {
            try performIO { try fileSystem.writeExclusively(data, to: url) }
        } else {
            try performIO { try fileSystem.writeAtomically(data, to: url) }
        }
        return SavedFilterRecord(filters: filters, revision: FileRevision(data: data))
    }

    private func filterDocument(_ data: Data) throws -> MarkdownDocument {
        guard let source = String(data: data, encoding: .utf8) else {
            throw SavedFilterError.invalidFormat("The file must be UTF-8.")
        }
        return try MarkdownDocument.parse(source)
    }

    private func savedFilterURL() throws -> URL {
        let components = [".localtodo", LocalTodoSchema.manifestPath, Self.savedFiltersPath]
        for component in components {
            try validateFilterComponent(component)
        }
        _ = try VaultScanner(root: root, fileSystem: fileSystem).loadConfiguration()
        return root.appendingPathComponent(Self.savedFiltersPath)
    }

    private func validateFilterComponent(_ component: String) throws {
        if try performIO({ try fileSystem.isSymbolicLink(at: root.appendingPathComponent(component)) }) {
            throw VaultStoreError.invalidVault("Saved filter metadata must not use symbolic links.")
        }
    }
}

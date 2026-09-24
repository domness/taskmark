import Foundation
import LocalTodoDomain

public extension VaultStore {
    func planOrganizationRemoval(
        _ removal: OrganizationRemoval, expectedRevision: FileRevision? = nil
    ) throws -> OrganizationChangeSet {
        let snapshot = try snapshot()
        guard !snapshot.diagnostics.contains(where: { $0.severity == .error }) else {
            throw VaultStoreError.invalidVault("Resolve the vault’s file errors before removing organization metadata.")
        }
        let collection = try removalCollection(removal, expectedRevision: expectedRevision)
        var steps = [OrganizationChange]()
        let records = snapshot.tasks.values.map { VaultRecord(
            value: LocalTodoEntity.task($0.value),
            revision: $0.revision
        ) }
            + snapshot.projects.values.map { VaultRecord(value: .project($0.value), revision: $0.revision) }
            + snapshot.areas.values.map { VaultRecord(value: .area($0.value), revision: $0.revision) }
        for record in records.sorted(by: { $0.value.path.value < $1.value.path.value }) {
            guard record.value.path != collection?.0 else { continue }
            if let step = try removalEdit(removal, record: record) {
                steps.append(step)
            }
        }
        if let filters = try removalFilters(removal) {
            steps.append(filters)
        }
        if let (path, data) = collection {
            steps.append(.delete(path, data))
        }
        return OrganizationChangeSet(steps: steps)
    }

    /// Stops at the first failure. Completed steps remain visible and reversible; retry replans remaining work.
    func applyOrganizationChanges(_ changes: OrganizationChangeSet, now: Date) -> OrganizationChangeResult {
        var completed = [OrganizationChange]()
        var records = [VaultRecord<LocalTodoEntity>]()
        var deleted = Set<VaultPath>()
        var filters: SavedFilterRecord?
        var message: String?
        for step in changes.steps {
            do {
                switch step {
                case let .edit(path, key, before, after):
                    try records.append(applyOrganizationEdit(path, key: key, before: before, after: after, now: now))
                case let .filters(before, after):
                    let current = try savedFilters()
                    guard current.filters == before else { throw SavedFilterError.conflict }
                    filters = try saveFilters(after, expectedRevision: current.revision)
                case let .delete(path, data):
                    _ = try delete(at: path, expectedRevision: FileRevision(data: data))
                    deleted.insert(path)
                case let .restore(path, data):
                    try records.append(restoreEntityContent(data, at: path))
                }
                completed.append(step)
            } catch {
                message = "Organization removal stopped after \(completed.count) change(s). "
                    + "Completed changes were kept and can be undone. \(error.localizedDescription)"
                break
            }
        }
        return OrganizationChangeResult(
            undo: OrganizationChangeSet(steps: completed).inverse,
            records: records, deletedPaths: deleted, filters: filters, errorMessage: message
        )
    }
}

private extension VaultStore {
    func removalFilters(_ removal: OrganizationRemoval) throws -> OrganizationChange? {
        let filters = try savedFilters().filters
        let updated = try filters.map { filter in
            var query = filter.query
            switch removal {
            case let .project(path):
                if query.filters.project == path {
                    query.filters.project = nil
                }
            case let .area(path):
                if query.filters.area == path {
                    query.filters.area = nil
                }
            case let .tag(tag): query.filters.tags.remove(tag)
            }
            return try SavedTaskFilter(name: filter.name, query: query)
        }
        return updated == filters ? nil : .filters(before: filters, after: updated)
    }

    func removalCollection(
        _ removal: OrganizationRemoval, expectedRevision: FileRevision?
    ) throws -> (VaultPath, Data)? {
        let path: VaultPath
        switch removal {
        case let .project(value), let .area(value): path = value
        case .tag: return nil
        }
        guard let expectedRevision else { throw VaultStoreError.conflict(path) }
        let data = try entityContent(at: path, expectedRevision: expectedRevision)
        let entity = try EntityDocumentCodec.decode(parseDocument(data, at: path), at: path)
        switch (removal, entity) {
        case (.project, .project), (.area, .area): return (path, data)
        default: throw VaultStoreError.wrongEntityType(path)
        }
    }

    func removalEdit(
        _ removal: OrganizationRemoval, record: VaultRecord<LocalTodoEntity>
    ) throws -> OrganizationChange? {
        let path = record.value.path
        let before = try entityContent(at: path, expectedRevision: record.revision)
        var document = try parseDocument(before, at: path)
        let key: FrontmatterKey
        switch removal {
        case let .project(project):
            guard case .task = record.value, document.string(forKey: "project") == project.value else { return nil }
            key = .project
            document.set(.remove, for: key)
        case let .area(area):
            guard document.string(forKey: "area") == area.value else { return nil }
            if case .area = record.value {
                return nil
            }
            key = .area
            document.set(.remove, for: key)
        case let .tag(tag):
            guard let tags = document.strings(forKey: "tags"), tags.contains(tag) else { return nil }
            key = .tags
            document.set(.strings(tags.filter { $0 != tag }), for: key)
        }
        _ = try EntityDocumentCodec.decode(document, at: path)
        return try .edit(path, key, before: before, after: renderedData(document))
    }

    func applyOrganizationEdit(
        _ path: VaultPath, key: FrontmatterKey, before: Data, after: Data, now: Date
    ) throws -> VaultRecord<LocalTodoEntity> {
        try validateEntityPath(path)
        let url = fileURL(for: path)
        var result: VaultRecord<LocalTodoEntity>?
        try performIO {
            try fileSystem.coordinateWriting(at: url, intent: .replacing) { coordinatedURL in
                guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else {
                    throw VaultStoreError.conflict(path)
                }
                try validateEntityPath(path)
                var current = try parseDocument(fileSystem.read(at: coordinatedURL), at: path)
                let original = try parseDocument(before, at: path)
                let replacement = try parseDocument(after, at: path)
                let entity = try EntityDocumentCodec.decode(current, at: path)
                guard try sameKind(entity, EntityDocumentCodec.decode(original, at: path)),
                      current.node(forKey: key.rawValue) == original.node(forKey: key.rawValue)
                else {
                    throw VaultStoreError.conflict(path)
                }
                current.setNode(replacement.node(forKey: key.rawValue), forKey: key.rawValue)
                current.set(.string(ISO8601DateFormatter().string(from: now)), for: .updatedAt)
                let updated = try EntityDocumentCodec.decode(current, at: path)
                let data = try renderedData(current)
                try fileSystem.writeAtomically(data, to: coordinatedURL)
                result = VaultRecord(value: updated, revision: FileRevision(data: data))
            }
        }
        guard let result else { throw VaultStoreError.inputOutput("Coordinated organization edit did not run") }
        return result
    }
}

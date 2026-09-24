import Foundation
import LocalTodoDomain

public enum OrganizationRemoval: Equatable, Sendable {
    case project(VaultPath)
    case area(VaultPath)
    case tag(String)
}

/// A sequence of individually atomic changes, not a multi-file transaction.
public struct OrganizationChangeSet: Sendable {
    let steps: [OrganizationChange]

    public var isEmpty: Bool {
        steps.isEmpty
    }

    public var paths: Set<VaultPath> {
        Set(steps.compactMap(\.path))
    }

    public var inverse: Self {
        Self(steps: steps.reversed().map(\.inverse))
    }
}

enum OrganizationChange: Sendable {
    case edit(VaultPath, FrontmatterKey, before: Data, after: Data)
    case filters(before: [SavedTaskFilter], after: [SavedTaskFilter])
    case delete(VaultPath, Data)
    case restore(VaultPath, Data)

    var path: VaultPath? {
        switch self {
        case let .edit(path, _, _, _), let .delete(path, _), let .restore(path, _): path
        case .filters: nil
        }
    }

    var inverse: Self {
        switch self {
        case let .edit(path, key, before, after): .edit(path, key, before: after, after: before)
        case let .filters(before, after): .filters(before: after, after: before)
        case let .delete(path, data): .restore(path, data)
        case let .restore(path, data): .delete(path, data)
        }
    }
}

public struct OrganizationChangeResult: Sendable {
    public let undo: OrganizationChangeSet
    public let records: [VaultRecord<LocalTodoEntity>]
    public let deletedPaths: Set<VaultPath>
    public let filters: SavedFilterRecord?
    public let errorMessage: String?
}

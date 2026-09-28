import LocalTodoDomain
import LocalTodoMarkdown

public struct WorkspaceViewOptions: Equatable, Sendable {
    public enum Grouping: String, CaseIterable, Sendable { case none, project, area }

    public var showsProject: Bool
    public var showsArea: Bool
    public var showsTags: Bool
    public var grouping: Grouping
    public var sort: TaskSort?

    public init(
        showsProject: Bool = true,
        showsArea: Bool = true,
        showsTags: Bool = true,
        grouping: Grouping = .none,
        sort: TaskSort? = nil
    ) {
        self.showsProject = showsProject
        self.showsArea = showsArea
        self.showsTags = showsTags
        self.grouping = grouping
        self.sort = sort
    }

    init(_ value: ConfigurationValue?) {
        let values: [String: ConfigurationValue] = if case let .object(values) = value {
            values
        } else {
            [:]
        }
        self.init(
            showsProject: values["showsProject"]?.boolValue ?? true,
            showsArea: values["showsArea"]?.boolValue ?? true,
            showsTags: values["showsTags"]?.boolValue ?? true,
            grouping: values["grouping"]?.stringValue.flatMap(Grouping.init(rawValue:)) ?? .none,
            sort: values["sort"]?.stringValue.flatMap(TaskSort.init(rawValue:))
        )
    }

    var configurationValue: ConfigurationValue {
        .object([
            "showsProject": .bool(showsProject),
            "showsArea": .bool(showsArea),
            "showsTags": .bool(showsTags),
            "grouping": .string(grouping.rawValue),
            "sort": sort.map { .string($0.rawValue) } ?? .null,
        ])
    }
}

public struct WorkspaceCustomOrder: Equatable, Sendable {
    public var isEnabled: Bool
    public var paths: [VaultPath]

    public init(isEnabled: Bool = false, paths: [VaultPath] = []) {
        self.isEnabled = isEnabled
        self.paths = paths
    }

    init(_ value: ConfigurationValue?) {
        let values: [String: ConfigurationValue] = if case let .object(values) = value {
            values
        } else {
            [:]
        }
        let paths: [VaultPath] = if case let .array(items) = values["paths"] {
            items.compactMap(\.stringValue).compactMap { try? VaultPath($0) }
        } else {
            []
        }
        self.init(isEnabled: values["isEnabled"]?.boolValue ?? false, paths: paths)
    }

    var configurationValue: ConfigurationValue {
        .object([
            "isEnabled": .bool(isEnabled),
            "paths": .array(paths.map { .string($0.value) }),
        ])
    }
}

private extension ConfigurationValue {
    var boolValue: Bool? {
        if case let .bool(value) = self {
            value
        } else {
            nil
        }
    }

    var stringValue: String? {
        if case let .string(value) = self {
            value
        } else {
            nil
        }
    }
}

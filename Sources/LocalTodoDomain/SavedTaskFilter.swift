import Foundation

public struct SavedTaskFilter: Equatable, Sendable {
    public let name: String
    public let query: TaskQuery

    public init(name: String, query: TaskQuery) throws {
        guard !name.isEmpty, name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.contains(where: \.isNewline), TaskView(scope: query.scope) != nil,
              query.filters.scheduled.isValid, query.filters.deadline.isValid
        else { throw DomainValidationError.invalidSavedFilter }
        try TagValidation.validate(query.filters.tags.sorted())
        for path in [query.filters.project, query.filters.area].compactMap(\.self) {
            guard try VaultPath(path.value) == path else { throw DomainValidationError.invalidVaultPath }
        }
        self.name = name
        self.query = query
    }

    public func missingReferences(projects: Set<VaultPath>, areas: Set<VaultPath>) -> [VaultPath] {
        var missing: [VaultPath] = []
        if let project = query.filters.project, !projects.contains(project) {
            missing.append(project)
        }
        if let area = query.filters.area, !areas.contains(area) {
            missing.append(area)
        }
        return missing
    }
}

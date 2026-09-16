import LocalTodoDomain

extension VaultStore {
    func filterDiagnostics(in snapshot: VaultSnapshot) -> [VaultDiagnostic] {
        do {
            let record = try savedFilters()
            return record.filters.flatMap { filter in
                filter.missingReferences(projects: Set(snapshot.projects.keys), areas: Set(snapshot.areas.keys)).map {
                    VaultDiagnostic(
                        severity: .error,
                        kind: .referenceMissing,
                        message: "Saved filter ‘\(filter.name)’ in \(Self.savedFiltersPath) "
                            + "references missing \($0.value).",
                        field: "filters",
                        reference: $0
                    )
                }
            }
        } catch {
            let diagnostic = VaultDiagnostic(
                severity: .error,
                kind: .fieldInvalid,
                message: "\(Self.savedFiltersPath): \(error.localizedDescription)",
                field: "filters"
            )
            return [diagnostic]
        }
    }
}

import LocalTodoMarkdown

extension VaultSnapshot {
    func hasSameContent(as other: VaultSnapshot) -> Bool {
        configuration == other.configuration && tasks == other.tasks
            && projects == other.projects && areas == other.areas
            && diagnostics == other.diagnostics && scanCompleteness == other.scanCompleteness
            && availability == other.availability && providerConflicts == other.providerConflicts
    }
}

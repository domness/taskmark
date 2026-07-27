import LocalTodoDomain

public struct VaultSnapshot: Equatable, Sendable {
    public let generation: UInt64
    public let configuration: VaultConfiguration
    public let tasks: [VaultPath: VaultRecord<TodoTask>]
    public let projects: [VaultPath: VaultRecord<Project>]
    public let areas: [VaultPath: VaultRecord<Area>]
    public let diagnostics: [VaultDiagnostic]

    public init(
        generation: UInt64,
        configuration: VaultConfiguration,
        tasks: [VaultPath: VaultRecord<TodoTask>],
        projects: [VaultPath: VaultRecord<Project>],
        areas: [VaultPath: VaultRecord<Area>],
        diagnostics: [VaultDiagnostic]
    ) {
        self.generation = generation
        self.configuration = configuration
        self.tasks = tasks
        self.projects = projects
        self.areas = areas
        self.diagnostics = diagnostics
    }
}

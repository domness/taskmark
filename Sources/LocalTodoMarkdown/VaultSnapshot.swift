import Foundation
import LocalTodoDomain

public enum VaultScanCompleteness: Equatable, Sendable {
    case complete
    case partial(String)
}

public struct VaultSnapshot: Equatable, Sendable {
    public let generation: UInt64
    public let configuration: VaultConfiguration
    public let tasks: [VaultPath: VaultRecord<TodoTask>]
    public let projects: [VaultPath: VaultRecord<Project>]
    public let areas: [VaultPath: VaultRecord<Area>]
    public let diagnostics: [VaultDiagnostic]
    public let scanCompleteness: VaultScanCompleteness
    public let availability: [VaultPath: VaultItemAvailability]
    public let providerConflicts: [String: VaultProviderConflict]

    public init(
        generation: UInt64,
        configuration: VaultConfiguration,
        tasks: [VaultPath: VaultRecord<TodoTask>],
        projects: [VaultPath: VaultRecord<Project>],
        areas: [VaultPath: VaultRecord<Area>],
        diagnostics: [VaultDiagnostic],
        scanCompleteness: VaultScanCompleteness = .complete,
        availability: [VaultPath: VaultItemAvailability] = [:],
        providerConflicts: [String: VaultProviderConflict] = [:]
    ) {
        self.generation = generation
        self.configuration = configuration
        self.tasks = tasks
        self.projects = projects
        self.areas = areas
        self.diagnostics = diagnostics
        self.scanCompleteness = scanCompleteness
        self.availability = availability
        self.providerConflicts = providerConflicts
    }
}

public struct VaultProviderConflict: Equatable, Sendable, Identifiable {
    public var id: String {
        path
    }

    public let path: String
    public let currentContent: Data
    public let currentRevision: FileRevision
    public let alternatives: [VaultProviderVersion]

    public init(path: String, currentContent: Data, alternatives: [VaultProviderVersion]) {
        self.path = path
        self.currentContent = currentContent
        currentRevision = FileRevision(data: currentContent)
        self.alternatives = alternatives
    }
}

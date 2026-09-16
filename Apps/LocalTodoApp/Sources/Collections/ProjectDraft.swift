import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Observation

enum ProjectDraftField: String, CaseIterable, Sendable {
    case title = "Title"
    case notes = "Notes"
    case status = "Status"
}

@MainActor
@Observable
final class ProjectDraft {
    let path: VaultPath
    let vaultSession: UUID
    var source: Project
    var revision: FileRevision
    var title: String {
        didSet { changed(.title) }
    }

    var notes: String {
        didSet { changed(.notes) }
    }

    var status: ProjectStatus {
        didSet { changed(.status) }
    }

    var isSaving = false
    var generation: UInt64 = 0
    var conflicts = Set<ProjectDraftField>()
    var unavailableMessage: String?
    var saveError: String?
    @ObservationIgnored private var isResetting = false
    @ObservationIgnored var onChange: ((ProjectDraft) -> Void)?

    init(_ record: VaultRecord<Project>, session: UUID) {
        path = record.value.path
        vaultSession = session
        source = record.value
        revision = record.revision
        title = record.value.title
        notes = record.value.body
        status = record.value.status
    }

    var isDirty: Bool {
        !changedFields(from: source).isEmpty
    }

    var canSave: Bool {
        isDirty && conflicts.isEmpty && unavailableMessage == nil && validationError == nil
    }

    var validationError: String? {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter a project title to save." : nil
    }

    func patch() -> ProjectPatch {
        var patch = ProjectPatch()
        if title != source.title {
            patch.title = .set(title)
        }
        if notes != source.body {
            patch.body = .set(notes)
        }
        if status != source.status {
            patch.status = .set(status)
        }
        return patch
    }

    func value(_ field: ProjectDraftField) -> String {
        switch field {
        case .title: title
        case .notes: notes
        case .status: status.rawValue
        }
    }

    func set(_ field: ProjectDraftField, to value: String) {
        switch field {
        case .title: title = value
        case .notes: notes = value
        case .status:
            if let status = ProjectStatus(rawValue: value) {
                self.status = status
            }
        }
    }

    func reset(_ record: VaultRecord<Project>) {
        isResetting = true
        defer { isResetting = false }
        source = record.value
        revision = record.revision
        title = source.title
        notes = source.body
        status = source.status
        conflicts.removeAll()
        unavailableMessage = nil
        saveError = nil
    }

    func rebase(_ record: VaultRecord<Project>) {
        let local = changedFields(from: source)
        isResetting = true
        defer { isResetting = false }
        for field in ProjectDraftField.allCases {
            let external = value(field, in: record.value)
            if !local.contains(field) {
                set(field, to: external)
            } else if external != value(field, in: source), external != value(field) {
                conflicts.insert(field)
            }
            if external == value(field) {
                conflicts.remove(field)
            }
        }
        source = record.value
        revision = record.revision
        unavailableMessage = nil
    }

    func accept(_ record: VaultRecord<Project>, savedGeneration: UInt64) {
        if generation == savedGeneration {
            reset(record)
        } else {
            source = record.value
            revision = record.revision
        }
        saveError = nil
    }

    func keepLocalChanges() {
        conflicts.removeAll()
        generation += 1
        onChange?(self)
    }

    private func changed(_ field: ProjectDraftField) {
        guard !isResetting else { return }
        conflicts.remove(field)
        generation += 1
        onChange?(self)
    }

    private func changedFields(from project: Project) -> Set<ProjectDraftField> {
        Set(ProjectDraftField.allCases.filter { value($0) != value($0, in: project) })
    }

    private func value(_ field: ProjectDraftField, in project: Project) -> String {
        switch field {
        case .title: project.title
        case .notes: project.body
        case .status: project.status.rawValue
        }
    }
}

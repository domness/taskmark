import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Observation

@MainActor
@Observable
final class TaskDraft {
    let path: VaultPath
    let vaultSession: UUID
    var sourceTask: TodoTask
    var revision: FileRevision
    var isDirty = false
    private(set) var isSaving = false
    var generation: UInt64 = 0
    var conflictedFields = Set<TaskDraftField>()
    var sourceUnavailableMessage: String?
    var canRecreateSource = false
    var isPlanningTransition = false

    var title: String {
        didSet { markDirty(.title) }
    }

    var status: TaskStatus {
        didSet { markDirty(.status) }
    }

    var priority: TaskPriority? {
        didSet { markDirty(.priority) }
    }

    var scheduled: String {
        didSet { markDirty(.scheduled) }
    }

    var deadline: String {
        didSet { markDirty(.deadline) }
    }

    var project: String {
        didSet { markDirty(.project) }
    }

    var area: String {
        didSet { markDirty(.area) }
    }

    var tags: [String] {
        didSet { markDirty(.tags) }
    }

    var notes: String {
        didSet { markDirty(.notes) }
    }

    var recurrence: TaskRecurrence? {
        didSet { markDirty(.recurrence) }
    }

    var resetChecklistOnRepeat: Bool {
        didSet { markDirty(.resetChecklistOnRepeat) }
    }

    @ObservationIgnored var isResetting = false
    @ObservationIgnored var onChange: ((TaskDraft) -> Void)?

    init(record: VaultRecord<TodoTask>, vaultSession: UUID) {
        let task = record.value
        path = task.path
        self.vaultSession = vaultSession
        sourceTask = task
        revision = record.revision
        title = task.title
        status = task.status
        priority = task.priority
        scheduled = task.scheduled?.description ?? ""
        deadline = task.deadline?.description ?? ""
        project = task.project?.value ?? ""
        area = task.area?.value ?? ""
        tags = task.tags
        notes = task.body
        recurrence = task.recurrence
        resetChecklistOnRepeat = task.resetChecklistOnRepeat
    }

    func patch() throws -> TaskPatch {
        var patch = TaskPatch()
        if title != sourceTask.title {
            patch.title = .set(title)
        }
        if status != sourceTask.status {
            patch.status = .set(status)
        }
        if priority != sourceTask.priority {
            patch.priority = .set(priority)
        }
        if scheduled != (sourceTask.scheduled?.description ?? "") {
            patch.scheduled = try .set(optionalDate(scheduled))
        }
        if deadline != (sourceTask.deadline?.description ?? "") {
            patch.deadline = try .set(optionalDate(deadline))
        }
        if project != (sourceTask.project?.value ?? "") {
            patch.project = try .set(optionalPath(project))
        }
        if area != (sourceTask.area?.value ?? "") {
            patch.area = try .set(optionalPath(area))
        }
        if tags != sourceTask.tags {
            patch.tags = .set(tags)
        }
        if notes != sourceTask.body {
            patch.body = .set(notes)
        }
        applyRecurrence(to: &patch)
        return patch
    }

    private func applyRecurrence(to patch: inout TaskPatch) {
        if recurrence != sourceTask.recurrence {
            patch.recurrence = .set(recurrence)
        }
        if resetChecklistOnRepeat != sourceTask.resetChecklistOnRepeat {
            patch.resetChecklistOnRepeat = .set(resetChecklistOnRepeat)
        }
    }

    var validationError: Error? {
        do {
            _ = try patch().applying(to: sourceTask, now: sourceTask.updatedAt)
            return nil
        } catch {
            return error
        }
    }

    var hasConflicts: Bool {
        !conflictedFields.isEmpty
    }

    func reset(to record: VaultRecord<TodoTask>) {
        isResetting = true
        defer { isResetting = false }
        let task = record.value
        sourceTask = task
        revision = record.revision
        title = task.title
        status = task.status
        priority = task.priority
        scheduled = task.scheduled?.description ?? ""
        deadline = task.deadline?.description ?? ""
        project = task.project?.value ?? ""
        area = task.area?.value ?? ""
        tags = task.tags
        notes = task.body
        recurrence = task.recurrence
        resetChecklistOnRepeat = task.resetChecklistOnRepeat
        isDirty = false
        isPlanningTransition = false
        conflictedFields.removeAll()
        sourceUnavailableMessage = nil
        canRecreateSource = false
    }

    func beginSaving() -> UInt64? {
        guard !isSaving else { return nil }
        isSaving = true
        return generation
    }

    func acceptSave(_ record: VaultRecord<TodoTask>, generation savedGeneration: UInt64) {
        if generation == savedGeneration {
            reset(to: record)
        } else {
            sourceTask = record.value
            revision = record.revision
            isDirty = hasChanges
        }
        isSaving = false
    }

    func finishSaving() {
        isSaving = false
    }

    func markSourceUnavailable(_ message: String, canRecreate: Bool) {
        sourceUnavailableMessage = message
        canRecreateSource = canRecreate
        isSaving = false
    }

    private func markDirty(_ field: TaskDraftField) {
        if !isResetting {
            conflictedFields.remove(field)
            isDirty = hasChanges
            generation += 1
            onChange?(self)
        }
    }

    var hasChanges: Bool {
        title != sourceTask.title
            || status != sourceTask.status
            || priority != sourceTask.priority
            || scheduled != (sourceTask.scheduled?.description ?? "")
            || deadline != (sourceTask.deadline?.description ?? "")
            || project != (sourceTask.project?.value ?? "")
            || area != (sourceTask.area?.value ?? "")
            || tags != sourceTask.tags
            || notes != sourceTask.body
            || recurrence != sourceTask.recurrence
            || resetChecklistOnRepeat != sourceTask.resetChecklistOnRepeat
    }

    private func optionalDate(_ value: String) throws -> CalendarDate? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : try CalendarDate(value)
    }

    private func optionalPath(_ value: String) throws -> VaultPath? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : try VaultPath(value)
    }
}

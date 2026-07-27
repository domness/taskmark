import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Observation

@MainActor
@Observable
final class TaskDraft {
    let path: VaultPath
    let vaultSession: UUID
    private(set) var sourceTask: TodoTask
    private(set) var revision: FileRevision
    private(set) var isDirty = false
    private(set) var isSaving = false
    private(set) var generation: UInt64 = 0

    var title: String {
        didSet { markDirty() }
    }

    var status: TaskStatus {
        didSet { markDirty() }
    }

    var priority: TaskPriority? {
        didSet { markDirty() }
    }

    var scheduled: String {
        didSet { markDirty() }
    }

    var deadline: String {
        didSet { markDirty() }
    }

    var project: String {
        didSet { markDirty() }
    }

    var area: String {
        didSet { markDirty() }
    }

    var tags: String {
        didSet { markDirty() }
    }

    var notes: String {
        didSet { markDirty() }
    }

    @ObservationIgnored private var isResetting = false

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
        tags = task.tags.joined(separator: ", ")
        notes = task.body
    }

    func patch() throws -> TaskPatch {
        var patch = TaskPatch()
        patch.title = .set(title)
        patch.status = .set(status)
        patch.priority = .set(priority)
        patch.scheduled = try .set(optionalDate(scheduled))
        patch.deadline = try .set(optionalDate(deadline))
        patch.project = try .set(optionalPath(project))
        patch.area = try .set(optionalPath(area))
        patch.tags = .set(tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        patch.body = .set(notes)
        return patch
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
        tags = task.tags.joined(separator: ", ")
        notes = task.body
        isDirty = false
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
        }
        isSaving = false
    }

    func finishSaving() {
        isSaving = false
    }

    private func markDirty() {
        if !isResetting {
            isDirty = true
            generation += 1
        }
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

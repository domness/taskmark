import LocalTodoDomain
import LocalTodoMarkdown

extension TaskDraft {
    func acceptFocusDropSave(
        _ record: VaultRecord<TodoTask>,
        generation savedGeneration: UInt64,
        fields: Set<TaskTransitionField>
    ) {
        let editedStatus = status != sourceTask.status
        let editedScheduled = scheduled != (sourceTask.scheduled?.description ?? "")
        let editedDeadline = deadline != (sourceTask.deadline?.description ?? "")
        let editedNotes = notes != sourceTask.body
        acceptSave(record, generation: savedGeneration)
        guard generation != savedGeneration else { return }
        isResetting = true
        if fields.contains(.status), !editedStatus {
            status = record.value.status
        }
        if fields.contains(.scheduled), !editedScheduled {
            scheduled = record.value.scheduled?.description ?? ""
        }
        if fields.contains(.deadline), !editedDeadline {
            deadline = record.value.deadline?.description ?? ""
        }
        if fields.contains(.body), !editedNotes {
            notes = record.value.body
        }
        isDirty = hasChanges
        isResetting = false
    }
}

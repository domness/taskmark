import LocalTodoDomain
import LocalTodoMarkdown

extension TaskDraft {
    func acceptOrganizationSave(
        _ record: VaultRecord<TodoTask>,
        generation savedGeneration: UInt64,
        field: TaskOrganizationField
    ) {
        let fieldWasEdited = switch field {
        case .project: project != (sourceTask.project?.value ?? "")
        case .area: area != (sourceTask.area?.value ?? "")
        }
        acceptSave(record, generation: savedGeneration)
        guard generation != savedGeneration, !fieldWasEdited else { return }
        isResetting = true
        switch field {
        case .project: project = record.value.project?.value ?? ""
        case .area: area = record.value.area?.value ?? ""
        }
        isDirty = hasChanges
        isResetting = false
    }
}

enum TaskOrganizationField {
    case project
    case area
}

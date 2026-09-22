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
        case .tags: tags != sourceTask.tags
        }
        acceptSave(record, generation: savedGeneration)
        guard generation != savedGeneration, !fieldWasEdited else { return }
        isResetting = true
        switch field {
        case .project: project = record.value.project?.value ?? ""
        case .area: area = record.value.area?.value ?? ""
        case .tags: tags = record.value.tags
        }
        isDirty = hasChanges
        isResetting = false
    }
}

enum TaskOrganizationField {
    case project
    case area
    case tags
}

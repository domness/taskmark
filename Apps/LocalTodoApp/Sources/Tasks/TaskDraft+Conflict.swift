import LocalTodoDomain
import LocalTodoMarkdown

extension TaskDraft {
    func rebase(to record: VaultRecord<TodoTask>) {
        let original = sourceTask
        let changedFields = fieldsChanged(from: original)
        let conflicts = conflictingFields(original: original, external: record.value)

        isResetting = true
        sourceTask = record.value
        revision = record.revision
        adoptExternalValues(from: record.value, except: changedFields)
        conflictedFields = conflictedFields.filter {
            localValue(for: $0) != value(for: $0, in: record.value)
        }
        conflictedFields.formUnion(conflicts)
        sourceUnavailableMessage = nil
        canRecreateSource = false
        isDirty = hasChanges
        isResetting = false

        if isDirty {
            generation += 1
            onChange?(self)
        }
    }

    func resolveConflictsKeepingLocalChanges() {
        guard hasConflicts else { return }
        conflictedFields.removeAll()
        generation += 1
        onChange?(self)
    }

    private func fieldsChanged(from task: TodoTask) -> Set<TaskDraftField> {
        var fields = Set<TaskDraftField>()
        if title != task.title {
            fields.insert(.title)
        }
        if status != task.status {
            fields.insert(.status)
        }
        if priority != task.priority {
            fields.insert(.priority)
        }
        if scheduled != (task.scheduled?.description ?? "") {
            fields.insert(.scheduled)
        }
        if deadline != (task.deadline?.description ?? "") {
            fields.insert(.deadline)
        }
        if project != (task.project?.value ?? "") {
            fields.insert(.project)
        }
        if area != (task.area?.value ?? "") {
            fields.insert(.area)
        }
        if tagValues != task.tags {
            fields.insert(.tags)
        }
        if notes != task.body {
            fields.insert(.notes)
        }
        return fields
    }

    private func conflictingFields(original: TodoTask, external: TodoTask) -> Set<TaskDraftField> {
        let localChanges = fieldsChanged(from: original)
        let externalChanges = fieldsChanged(in: external, from: original)
        var conflicts = localChanges.intersection(externalChanges)
        if original.recurrence != nil {
            // Recurring planning edits depend on the repeat rule and completion eligibility, not just date fields.
            if external.recurrence != original.recurrence {
                conflicts.formUnion(localChanges.intersection([.status, .scheduled, .deadline]))
            }
            if external.status != original.status {
                conflicts.formUnion(localChanges.intersection([.scheduled, .deadline]))
            }
        }
        return conflicts.filter { localValue(for: $0) != value(for: $0, in: external) }
    }

    private func fieldsChanged(in task: TodoTask, from original: TodoTask) -> Set<TaskDraftField> {
        var fields = Set<TaskDraftField>()
        for field in TaskDraftField.allCases where value(for: field, in: task) != value(for: field, in: original) {
            fields.insert(field)
        }
        return fields
    }

    private func adoptExternalValues(from task: TodoTask, except fields: Set<TaskDraftField>) {
        if !fields.contains(.title) {
            title = task.title
        }
        if !fields.contains(.status) {
            status = task.status
        }
        if !fields.contains(.priority) {
            priority = task.priority
        }
        if !fields.contains(.scheduled) {
            scheduled = task.scheduled?.description ?? ""
        }
        if !fields.contains(.deadline) {
            deadline = task.deadline?.description ?? ""
        }
        if !fields.contains(.project) {
            project = task.project?.value ?? ""
        }
        if !fields.contains(.area) {
            area = task.area?.value ?? ""
        }
        if !fields.contains(.tags) {
            tags = task.tags.joined(separator: ", ")
        }
        if !fields.contains(.notes) {
            notes = task.body
        }
    }

    private func localValue(for field: TaskDraftField) -> String {
        switch field {
        case .title: title
        case .status: status.rawValue
        case .priority: priority?.rawValue ?? ""
        case .scheduled: scheduled
        case .deadline: deadline
        case .project: project
        case .area: area
        case .tags: tagValues.joined(separator: "\n")
        case .notes: notes
        }
    }

    private func value(for field: TaskDraftField, in task: TodoTask) -> String {
        switch field {
        case .title: task.title
        case .status: task.status.rawValue
        case .priority: task.priority?.rawValue ?? ""
        case .scheduled: task.scheduled?.description ?? ""
        case .deadline: task.deadline?.description ?? ""
        case .project: task.project?.value ?? ""
        case .area: task.area?.value ?? ""
        case .tags: task.tags.joined(separator: "\n")
        case .notes: task.body
        }
    }
}

enum TaskDraftField: String, CaseIterable, Hashable {
    case title = "Title"
    case status = "Status"
    case priority = "Priority"
    case scheduled = "Scheduled"
    case deadline = "Deadline"
    case project = "Project"
    case area = "Area"
    case tags = "Tags"
    case notes = "Notes"
}

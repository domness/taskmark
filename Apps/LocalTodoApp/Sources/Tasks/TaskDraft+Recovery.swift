extension TaskDraft {
    func transferCurrentValues(to draft: TaskDraft) {
        draft.isResetting = true
        draft.title = title
        draft.status = status
        draft.priority = priority
        draft.scheduled = scheduled
        draft.deadline = deadline
        draft.project = project
        draft.area = area
        draft.tags = tags
        draft.notes = notes
        draft.recurrence = recurrence
        draft.resetChecklistOnRepeat = resetChecklistOnRepeat
        draft.isDirty = draft.hasChanges
        draft.isResetting = false
    }
}

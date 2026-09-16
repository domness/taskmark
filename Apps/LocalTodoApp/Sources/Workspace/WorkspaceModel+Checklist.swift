import LocalTodoDomain

extension WorkspaceModel {
    func setChecklistItem(
        _ item: MarkdownChecklist.Item, checked: Bool, in draft: TaskDraft, projection: MarkdownChecklist
    ) {
        guard draft.vaultSession == vaultSession, draft.notes == projection.body else {
            errorMessage = "The notes changed. Review the checklist and try again."
            return
        }
        guard !draft.hasConflicts, draft.sourceUnavailableMessage == nil else {
            errorMessage = "Resolve the task’s file changes before changing its checklist."
            return
        }
        do {
            let notes = try projection.settingChecked(checked, item: item)
            changeDraft(draft, keyPath: \.notes, to: notes, actionName: "Change Checklist")
        } catch {
            errorMessage = "The checklist item changed. Review the notes and try again."
        }
    }
}

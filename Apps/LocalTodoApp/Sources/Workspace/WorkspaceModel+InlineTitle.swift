import Foundation
import LocalTodoDomain

extension WorkspaceModel {
    func beginInlineTitleEditing(at path: VaultPath) {
        guard snapshot?.tasks[path] != nil else { return }
        selectTask(path)
        inlineTitleEditingPath = path
    }

    func finishInlineTitleEditing(_ draft: TaskDraft) {
        guard draft.vaultSession == vaultSession else { return }
        if inlineTitleEditingPath == draft.path {
            inlineTitleEditingPath = nil
        }
        if let message = draft.validationError {
            errorMessage = message.localizedDescription
            isInspectorPresented = true
        } else if draft.hasConflicts {
            isInspectorPresented = true
        }
        if draft.isDirty {
            scheduleAutosave(for: draft, delay: .zero)
        }
    }
}

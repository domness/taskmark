import Foundation
import LocalTodoDomain

extension WorkspaceModel {
    func changeTaskStatus(_ draft: TaskDraft, to status: TaskStatus, now: Date = Date()) {
        guard draft.vaultSession == vaultSession, draft.status != status, let snapshot else { return }
        guard status == .done, draft.sourceTask.recurrence != nil else {
            changeDraft(draft, keyPath: \.status, to: status, actionName: "Change Status")
            return
        }
        guard !draft.hasConflicts, draft.sourceUnavailableMessage == nil else {
            errorMessage = "Resolve the task's file changes before completing it."
            return
        }
        do {
            let current = try draft.patch().applying(to: draft.sourceTask, now: now)
            let completed = try TaskTransition.complete(
                current,
                now: now,
                today: today(configuration: snapshot.configuration, now: now),
                calendar: vaultCalendar
            )
            // Store the calculated dates in the draft: autosave retries and redo must not roll forward again.
            undoManager?.beginUndoGrouping()
            defer { undoManager?.endUndoGrouping() }
            changeDraft(draft, keyPath: \.status, to: completed.status, actionName: "Complete Task")
            changeDraft(draft, keyPath: \.notes, to: completed.body, actionName: "Complete Task")
            changeDraft(
                draft, keyPath: \.scheduled, to: completed.scheduled?.description ?? "", actionName: "Complete Task"
            )
            changeDraft(
                draft, keyPath: \.deadline, to: completed.deadline?.description ?? "", actionName: "Complete Task"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func updateProject(_ draft: ProjectDraft, retryingConflict: Bool = true) async {
        guard draft.vaultSession == vaultSession, draft.canSave, !draft.isSaving, let store else { return }
        guard beginMutation(at: draft.path) else {
            scheduleProjectAutosave(draft)
            return
        }
        draft.isSaving = true
        let generation = draft.generation
        do {
            let updated = try draft.patch().applying(to: draft.source, now: Date())
            let saved = try await store.update(.project(updated), expectedRevision: draft.revision)
            endMutation(at: draft.path)
            draft.isSaving = false
            guard draft.vaultSession == vaultSession, case let .project(project) = saved.value else { return }
            draft.accept(VaultRecord(value: project, revision: saved.revision), savedGeneration: generation)
            merge(saved)
            await refresh()
            if draft.canSave {
                scheduleProjectAutosave(draft)
            }
        } catch let error as VaultStoreError where error == .conflict(draft.path) {
            endMutation(at: draft.path)
            draft.isSaving = false
            await refresh()
            if retryingConflict, draft.canSave {
                await updateProject(draft, retryingConflict: false)
            }
        } catch {
            endMutation(at: draft.path)
            draft.isSaving = false
            guard draft.vaultSession == vaultSession else { return }
            draft.saveError = error.localizedDescription
            errorMessage = error.localizedDescription
            await refresh()
        }
    }
}

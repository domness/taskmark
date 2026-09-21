import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    var hasDirtyDrafts: Bool {
        taskDrafts.values.contains(where: \.isDirty) || projectDrafts.values.contains(where: \.isDirty)
    }

    var selectedProjectDraft: ProjectDraft? {
        guard case let .project(path) = route else { return nil }
        return projectDrafts[path]
    }

    var activeProjects: [Project] {
        projects(active: true)
    }

    var inactiveProjects: [Project] {
        projects(active: false)
    }

    private func projects(active: Bool) -> [Project] {
        (snapshot?.projects.values.map(\.value) ?? [])
            .filter { ($0.status == .active) == active }
            .sorted { $0.title == $1.title ? $0.path.value < $1.path.value : $0.title < $1.title }
    }

    func prepareProjectDraft() {
        guard case let .project(path) = route, projectDrafts[path] == nil,
              let record = snapshot?.projects[path] else { return }
        let draft = ProjectDraft(record, session: vaultSession)
        draft.onChange = { [weak self] in self?.scheduleProjectAutosave($0) }
        projectDrafts[path] = draft
    }

    func editProject() {
        prepareProjectDraft()
        selectedTaskPath = nil
        isInspectorPresented = true
        guard let path = selectedProjectDraft?.path else { return }
        titleEditingPath = path
        titleEditRequest += 1
    }

    func toggleProjectCompletion(_ draft: ProjectDraft, now: Date = Date()) {
        guard draft.vaultSession == vaultSession, draft.conflicts.isEmpty, draft.unavailableMessage == nil else {
            errorMessage = "Resolve the project’s file changes before changing its completion."
            return
        }
        do {
            let current = try draft.patch().applying(to: draft.source, now: now)
            let updated = current.status == .done || current.status == .canceled
                ? try ProjectTransition.reopen(current, now: now)
                : try ProjectTransition.complete(current, now: now)
            changeProjectField(draft, field: .status, to: updated.status.rawValue)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeProjectField(_ draft: ProjectDraft, field: ProjectDraftField, to value: String) {
        guard draft.vaultSession == vaultSession, draft.value(field) != value else { return }
        let previous = draft.value(field)
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.changeProjectField(draft, field: field, to: previous) }
        }
        undoManager?.setActionName("Change Project \(field.rawValue)")
        draft.set(field, to: value)
    }

    func discardProjectChanges(_ draft: ProjectDraft) {
        autosaveTasks.removeValue(forKey: draft.path)?.cancel()
        clearHistory()
        if let record = snapshot?.projects[draft.path] {
            draft.reset(record)
        } else {
            projectDrafts.removeValue(forKey: draft.path)
            route = .today
        }
    }

    func reconcileProjectDrafts(_ snapshot: VaultSnapshot) {
        for (path, draft) in projectDrafts {
            if let record = snapshot.projects[path] {
                guard record.revision != draft.revision || draft.unavailableMessage != nil else { continue }
                if draft.isDirty {
                    draft.rebase(record)
                } else {
                    draft.reset(record)
                }
                if draft.canSave {
                    scheduleProjectAutosave(draft)
                }
            } else if draft.isDirty {
                autosaveTasks.removeValue(forKey: path)?.cancel()
                draft.unavailableMessage = snapshot.diagnostics.first { $0.path == path }?.message
                    ?? "The project file is missing or is no longer a project. "
                    + "Restore the file or copy your notes before discarding changes."
            } else {
                projectDrafts.removeValue(forKey: path)
            }
        }
        prepareProjectDraft()
    }

    func scheduleProjectAutosave(_ draft: ProjectDraft) {
        guard draft.vaultSession == vaultSession else { return }
        autosaveTasks.removeValue(forKey: draft.path)?.cancel()
        autosaveTasks[draft.path] = Task { [weak self, weak draft] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self, let draft, draft.canSave else { return }
            await updateProject(draft)
        }
    }
}

import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    var hasPendingDocumentChanges: Bool {
        !pendingMutationPaths.isEmpty
            || isHistoryBusy
            || !quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || hasDirtyDrafts
            || filterState.isSaving
            || isSavingConfiguration
    }

    func flushTaskChanges() async -> Bool {
        for _ in 0 ..< 100 where !pendingMutationPaths.isEmpty || filterState.isSaving || isSavingConfiguration {
            try? await Task.sleep(for: .milliseconds(50))
        }
        for task in autosaveTasks.values {
            task.cancel()
        }
        autosaveTasks.removeAll()
        for draft in taskDrafts.values where draft.isDirty && !draft.hasConflicts && draft.validationError == nil {
            await updateTask(draft)
        }
        for draft in projectDrafts.values where draft.canSave {
            await updateProject(draft)
        }
        return pendingMutationPaths.isEmpty
            && !isHistoryBusy
            && quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hasDirtyDrafts
            && !filterState.isSaving
            && !isSavingConfiguration
    }

    func beginQuickCapture() {
        guard snapshot != nil else { return }
        quickCaptureGeneration &+= 1
        quickCaptureRoute = route
        isQuickCapturePresented = true
    }

    func cancelQuickCapture() {
        quickCaptureTitle = ""
        isQuickCapturePresented = false
    }

    func finishQuickCapture(title: String, generation: UInt64) {
        let current = quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard quickCaptureGeneration == generation, current.isEmpty || current == title else { return }
        quickCaptureTitle = ""
        isQuickCapturePresented = false
    }

    func selectTask(_ path: VaultPath?) {
        selectedTaskPath = path
        guard let path, let record = snapshot?.tasks[path] else { return }
        if taskDrafts[path] == nil {
            taskDrafts[path] = makeDraft(record: record)
        }
    }

    func editTask(at path: VaultPath) {
        selectTask(path)
        isInspectorPresented = true
        titleEditingPath = path
        titleEditRequest += 1
    }

    func consumeTitleEditRequest(at path: VaultPath) {
        if titleEditingPath == path {
            titleEditingPath = nil
        }
    }

    var selectedTaskDraft: TaskDraft? {
        guard let selectedTaskPath else { return nil }
        return taskDrafts[selectedTaskPath]
    }

    func discardChanges(for path: VaultPath) {
        autosaveTasks.removeValue(forKey: path)?.cancel()
        if let record = snapshot?.tasks[path] {
            taskDrafts[path]?.reset(to: record)
        } else {
            taskDrafts.removeValue(forKey: path)
            if selectedTaskPath == path {
                selectedTaskPath = nil
            }
        }
    }

    func reconcileDrafts(with snapshot: VaultSnapshot) async {
        var removedPaths = [VaultPath]()
        for (path, draft) in taskDrafts {
            if let record = snapshot.tasks[path] {
                guard draft.revision != record.revision || draft.sourceUnavailableMessage != nil else { continue }
                if draft.isDirty {
                    draft.rebase(to: record)
                } else {
                    draft.reset(to: record)
                }
            } else if draft.isDirty {
                autosaveTasks.removeValue(forKey: path)?.cancel()
                let detail = snapshot.diagnostics.first { $0.path == path }?.message
                    ?? "The task file was deleted or is no longer a valid task."
                let sourceExists = await store?.fileExists(at: path) ?? true
                draft.markSourceUnavailable(detail, canRecreate: !sourceExists)
            } else {
                removedPaths.append(path)
            }
        }
        for path in removedPaths {
            taskDrafts.removeValue(forKey: path)
        }
        guard let selectedTaskPath else { return }
        if taskDrafts[selectedTaskPath] == nil, let record = snapshot.tasks[selectedTaskPath] {
            taskDrafts[selectedTaskPath] = makeDraft(record: record)
        }
    }

    func makeDraft(record: VaultRecord<TodoTask>) -> TaskDraft {
        let draft = TaskDraft(record: record, vaultSession: vaultSession)
        draft.onChange = { [weak self] draft in
            self?.scheduleAutosave(for: draft)
        }
        return draft
    }
}

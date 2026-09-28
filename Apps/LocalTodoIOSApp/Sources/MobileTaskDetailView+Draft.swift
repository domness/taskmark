import LocalTodoDomain
import LocalTodoWorkspace

extension MobileTaskDetailView {
    func loadTask() async {
        guard let task else { return }
        title = task.title
        bodyText = task.body
        status = task.status
        priority = task.priority
        loadDates(from: task)
        projectPath = task.project?.value ?? ""
        areaPath = task.area?.value ?? ""
        tagsText = task.tags.joined(separator: "\n")
        recurrence = RecurrenceEditorValue(task.recurrence)
        resetChecklistOnRepeat = task.resetChecklistOnRepeat
        exactMarkdown = await workspace.taskMarkdown(at: path) ?? ""
        await loadCheckpoint()
    }

    func save() async {
        guard let task else { return }
        let patch = patch(for: task)
        guard await workspace.updateTask(at: path, patch: patch), let identifier = workspace.vaultIdentifier else {
            return
        }
        try? await workspace.checkpoints.remove(
            vaultIdentifier: identifier, path: path, through: checkpointGeneration
        )
        recoveredDraft = false
        pendingConflictedCheckpoint = nil
    }

    var draftFingerprint: String {
        [
            title, bodyText, status.rawValue, priority?.rawValue ?? "", scheduledDate.description,
            String(hasScheduledDate), deadlineDate.description, String(hasDeadlineDate), projectPath, areaPath,
            tagsText, recurrence.mode.rawValue, recurrence.frequency.rawValue, String(recurrence.interval),
            recurrence.weekdays.map(\.rawValue).joined(), recurrence.unit.rawValue, String(resetChecklistOnRepeat),
        ].joined(separator: "\u{1f}")
    }

    var hasChanges: Bool {
        guard let task else { return false }
        return title != task.title || bodyText != task.body || status != task.status || priority != task.priority
            || currentScheduled != task.scheduled || currentDeadline != task.deadline
            || optionalPath(projectPath) != task.project || optionalPath(areaPath) != task.area
            || currentTags != task.tags || (try? recurrence.recurrence()) != task.recurrence
            || resetChecklistOnRepeat != task.resetChecklistOnRepeat
    }

    var currentScheduled: CalendarDate? {
        hasScheduledDate ? try? CalendarDate(date: scheduledDate, calendar: vaultCalendar) : nil
    }

    var currentDeadline: CalendarDate? {
        hasDeadlineDate ? try? CalendarDate(date: deadlineDate, calendar: vaultCalendar) : nil
    }

    var currentTags: [String] {
        tagsText.split(whereSeparator: \.isNewline).map(String.init)
    }

    func optionalPath(_ value: String) -> VaultPath? {
        value.isEmpty ? nil : try? VaultPath(value)
    }

    func checkpointIfNeeded() async {
        guard hasChanges, let identifier = workspace.vaultIdentifier,
              let revision = workspace.snapshot?.tasks[path]?.revision.value else { return }
        checkpointGeneration += 1
        let checkpoint = TaskDraftCheckpoint(
            vaultIdentifier: identifier, path: path, baseRevision: revision, generation: checkpointGeneration,
            title: title, status: status, priority: priority, scheduled: currentScheduled, deadline: currentDeadline,
            project: optionalPath(projectPath), area: optionalPath(areaPath), tags: currentTags, body: bodyText,
            recurrence: recurrence, resetChecklistOnRepeat: resetChecklistOnRepeat
        )
        do {
            try await workspace.checkpoints.save(checkpoint)
        } catch {
            workspace.errorMessage = "The local recovery draft could not be saved. \(error.localizedDescription)"
        }
    }

    func applyPendingCheckpoint() {
        guard let checkpoint = pendingConflictedCheckpoint else { return }
        apply(checkpoint)
        recoveredDraft = true
        pendingConflictedCheckpoint = nil
    }

    func discardCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier else { return }
        try? await workspace.checkpoints.remove(
            vaultIdentifier: identifier, path: path, through: checkpointGeneration
        )
        pendingConflictedCheckpoint = nil
        recoveredDraft = false
    }

    private func loadDates(from task: TodoTask) {
        if let scheduled = task.scheduled, let date = try? scheduled.date(in: vaultCalendar) {
            scheduledDate = date
            hasScheduledDate = true
        } else {
            hasScheduledDate = false
        }
        if let deadline = task.deadline, let date = try? deadline.date(in: vaultCalendar) {
            deadlineDate = date
            hasDeadlineDate = true
        } else {
            hasDeadlineDate = false
        }
    }

    private func loadCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier,
              let checkpoint = try? await workspace.checkpoints.checkpoints().first(where: {
                  $0.vaultIdentifier == identifier && $0.path == path
              })
        else { return }
        checkpointGeneration = checkpoint.generation
        if checkpoint.baseRevision == workspace.snapshot?.tasks[path]?.revision.value {
            apply(checkpoint)
            recoveredDraft = true
        } else {
            pendingConflictedCheckpoint = checkpoint
        }
    }

    private func apply(_ checkpoint: TaskDraftCheckpoint) {
        title = checkpoint.title
        bodyText = checkpoint.body
        status = checkpoint.status
        priority = checkpoint.priority
        if let date = checkpoint.scheduled, let value = try? date.date(in: vaultCalendar) {
            scheduledDate = value
            hasScheduledDate = true
        } else {
            hasScheduledDate = false
        }
        if let date = checkpoint.deadline, let value = try? date.date(in: vaultCalendar) {
            deadlineDate = value
            hasDeadlineDate = true
        } else {
            hasDeadlineDate = false
        }
        projectPath = checkpoint.project?.value ?? ""
        areaPath = checkpoint.area?.value ?? ""
        tagsText = checkpoint.tags.joined(separator: "\n")
        recurrence = checkpoint.recurrence
        resetChecklistOnRepeat = checkpoint.resetChecklistOnRepeat
    }

    private func patch(for task: TodoTask) -> TaskPatch {
        var patch = TaskPatch()
        applyTextFields(to: &patch, task: task)
        applyPlanningFields(to: &patch, task: task)
        applyOrganizationFields(to: &patch, task: task)
        return patch
    }

    private func applyTextFields(to patch: inout TaskPatch, task: TodoTask) {
        if title != task.title {
            patch.title = .set(title)
        }
        if bodyText != task.body {
            patch.body = .set(bodyText)
        }
    }

    private func applyPlanningFields(to patch: inout TaskPatch, task: TodoTask) {
        if status != task.status {
            patch.status = .set(status)
        }
        if priority != task.priority {
            patch.priority = .set(priority)
        }
        if currentScheduled != task.scheduled {
            patch.scheduled = .set(currentScheduled)
        }
        if currentDeadline != task.deadline {
            patch.deadline = .set(currentDeadline)
        }
        if let value = try? recurrence.recurrence(), value != task.recurrence {
            patch.recurrence = .set(value)
        }
        if resetChecklistOnRepeat != task.resetChecklistOnRepeat {
            patch.resetChecklistOnRepeat = .set(resetChecklistOnRepeat)
        }
    }

    private func applyOrganizationFields(to patch: inout TaskPatch, task: TodoTask) {
        let project = optionalPath(projectPath)
        if project != task.project {
            patch.project = .set(project)
        }
        let area = optionalPath(areaPath)
        if area != task.area {
            patch.area = .set(area)
        }
        if currentTags != task.tags {
            patch.tags = .set(currentTags)
        }
    }
}

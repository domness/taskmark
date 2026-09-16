import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var visibleTasks: [TodoTask] {
        guard let snapshot, let today = try? today(configuration: snapshot.configuration) else {
            return []
        }
        if route == .search, !hasActiveSearch {
            return []
        }
        let scope: TaskScope = switch route {
        case .today: .today
        case .inbox: .inbox
        case .next: .next
        case .all, .search, .issues: .all
        case let .project(path): .project(path)
        case let .area(path): .area(path)
        case let .tag(tag): .tag(tag)
        case let .priority(priority): .priority(priority)
        }
        let query = TaskQuery(
            scope: scope,
            text: route == .search ? searchText.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            includeCompleted: route == .all || route == .search
        )
        return query.results(from: snapshot.tasks.values.map(\.value), today: today)
    }

    var allTags: [String] {
        guard let snapshot else { return [] }
        let values = snapshot.tasks.values.flatMap(\.value.tags)
            + snapshot.projects.values.flatMap(\.value.tags)
            + snapshot.areas.values.flatMap(\.value.tags)
        return Array(Set(values)).sorted()
    }

    func beginSearch() {
        route = .search
        searchFocusRequest += 1
    }

    func createTask(title: String, vaultSession intentSession: UUID) async {
        guard intentSession == vaultSession, let store, let snapshot else { return }
        var mutationPath: VaultPath?
        do {
            let now = Date()
            let path = try nextTaskPath(title: title, snapshot: snapshot)
            let task = try TodoTask(
                path: path,
                title: title,
                status: .inbox,
                createdAt: now,
                updatedAt: now
            )
            mutationPath = path
            guard beginMutation(at: path) else { return }
            let record = try await store.create(.task(task))
            endMutation(at: path)
            guard intentSession == vaultSession else { return }
            merge(record)
            registerHistory(replacingWith: nil, at: path, actionName: "Create Task")
            quickCaptureTitle = ""
            isQuickCapturePresented = false
            await refresh()
            selectTask(path)
        } catch {
            if let mutationPath {
                endMutation(at: mutationPath)
            }
            errorMessage = error.localizedDescription
        }
    }

    func completeTask(
        at path: VaultPath,
        expectedRevision: FileRevision,
        vaultSession intentSession: UUID
    ) async {
        guard intentSession == vaultSession else { return }
        guard let store, let snapshot, let record = snapshot.tasks[path], record.revision == expectedRevision else {
            errorMessage = "The task changed before completion. Local Todo refreshed it; try again."
            return
        }
        guard beginMutation(at: path) else { return }
        do {
            let now = Date()
            let task = record.value
            let previousStatus = completedTaskStatuses[path] ?? .inbox
            let updated = task.status.isComplete
                ? try TaskTransition.reopen(task, status: previousStatus, now: now)
                : try TaskTransition.complete(
                    task,
                    now: now,
                    today: today(configuration: snapshot.configuration, now: now),
                    calendar: calendar(configuration: snapshot.configuration)
                )
            let saved = try await store.update(.task(updated), expectedRevision: record.revision)
            endMutation(at: path)
            guard intentSession == vaultSession else { return }
            merge(saved)
            if task.status.isComplete {
                completedTaskStatuses.removeValue(forKey: path)
            } else if updated.status.isComplete {
                completedTaskStatuses[path] = task.status
            }
            registerTaskTransitionHistory(
                restoring: task,
                fields: transitionFields(from: task, to: updated),
                actionName: task.status.isComplete ? "Reopen Task" : "Complete Task"
            )
            await refresh()
        } catch {
            endMutation(at: path)
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ draft: TaskDraft, retryingConflict: Bool = true) async {
        guard let context = beginTaskUpdate(draft) else { return }
        do {
            let patch = try draft.patch()
            let updated = try patch.applying(to: draft.sourceTask, now: Date())
            let record = try await context.store.update(.task(updated), expectedRevision: draft.revision)
            endMutation(at: draft.path)
            guard context.session == vaultSession else {
                draft.finishSaving()
                return
            }
            guard case let .task(savedTask) = record.value else {
                throw VaultStoreError.wrongEntityType(draft.path)
            }
            draft.acceptSave(
                VaultRecord(value: savedTask, revision: record.revision),
                generation: context.generation
            )
            merge(record)
            await refresh()
        } catch let error as VaultStoreError where error == .conflict(draft.path) {
            await handleTaskConflict(draft, shouldRetry: retryingConflict)
        } catch let error as VaultStoreError {
            endMutation(at: draft.path)
            draft.finishSaving()
            switch error {
            case .notFound, .wrongEntityType:
                autosaveTasks.removeValue(forKey: draft.path)?.cancel()
                let sourceExists = await store?.fileExists(at: draft.path) ?? true
                draft.markSourceUnavailable(error.localizedDescription, canRecreate: !sourceExists)
            default:
                errorMessage = error.localizedDescription
                scheduleAutosave(for: draft, delay: .seconds(2))
            }
        } catch {
            endMutation(at: draft.path)
            draft.finishSaving()
            errorMessage = error.localizedDescription
            scheduleAutosave(for: draft, delay: .seconds(2))
        }
    }

    private func beginTaskUpdate(_ draft: TaskDraft) -> TaskUpdateContext? {
        guard draft.vaultSession == vaultSession,
              !draft.hasConflicts,
              draft.sourceUnavailableMessage == nil,
              draft.validationError == nil
        else { return nil }
        guard !pendingMutationPaths.contains(draft.path) else {
            scheduleAutosave(for: draft, delay: .milliseconds(200))
            return nil
        }
        guard let store, let generation = draft.beginSaving(), beginMutation(at: draft.path) else {
            draft.finishSaving()
            scheduleAutosave(for: draft, delay: .milliseconds(200))
            return nil
        }
        return TaskUpdateContext(store: store, generation: generation, session: vaultSession)
    }

    private func handleTaskConflict(_ draft: TaskDraft, shouldRetry: Bool) async {
        endMutation(at: draft.path)
        draft.finishSaving()
        await refresh()
        if shouldRetry, draft.isDirty, !draft.hasConflicts, draft.validationError == nil {
            await updateTask(draft, retryingConflict: false)
        } else if !draft.hasConflicts {
            errorMessage = "The task kept changing while Local Todo was saving. Your edits remain in the inspector."
        }
    }

    func scheduleAutosave(for draft: TaskDraft, delay: Duration = .milliseconds(500)) {
        guard draft.vaultSession == vaultSession else { return }
        autosaveTasks.removeValue(forKey: draft.path)?.cancel()
        let session = vaultSession
        autosaveTasks[draft.path] = Task { [weak self, weak draft] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, let draft, session == vaultSession else { return }
            guard draft.isDirty,
                  !draft.hasConflicts,
                  draft.sourceUnavailableMessage == nil,
                  draft.validationError == nil
            else { return }
            await updateTask(draft)
        }
    }

    var vaultCalendar: Calendar {
        snapshot.map { calendar(configuration: $0.configuration) } ?? Calendar(identifier: .gregorian)
    }

    func nextTaskPath(title: String, snapshot: VaultSnapshot) throws -> VaultPath {
        let slug = title.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = slug.isEmpty ? "task" : slug
        var suffix = 1
        while true {
            let name = suffix == 1 ? base : "\(base)-\(suffix)"
            let path = try VaultPath("Tasks/\(name).md")
            if snapshot.tasks[path] == nil, snapshot.projects[path] == nil, snapshot.areas[path] == nil {
                return path
            }
            suffix += 1
        }
    }

    private func transitionFields(from task: TodoTask, to updated: TodoTask) -> Set<TaskTransitionField> {
        var fields = Set<TaskTransitionField>()
        if task.body != updated.body {
            fields.insert(.body)
        }
        if task.status != updated.status {
            fields.insert(.status)
        }
        if task.scheduled != updated.scheduled {
            fields.insert(.scheduled)
        }
        if task.deadline != updated.deadline {
            fields.insert(.deadline)
        }
        if task.completedAt != updated.completedAt {
            fields.insert(.completedAt)
        }
        return fields
    }

    func today(configuration: VaultConfiguration, now: Date = Date()) throws -> CalendarDate {
        let calendar = calendar(configuration: configuration)
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            throw DomainValidationError.invalidCalendarDate
        }
        return try CalendarDate(year: year, month: month, day: day)
    }

    private func calendar(configuration: VaultConfiguration) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = configuration.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        return calendar
    }
}

private struct TaskUpdateContext {
    let store: VaultStore
    let generation: UInt64
    let session: UUID
}

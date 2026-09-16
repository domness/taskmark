import Foundation
import LocalTodoDomain

extension WorkspaceModel {
    var selectedTaskIsComplete: Bool {
        if let draft = selectedTaskDraft {
            return draft.status.isComplete
        }
        guard let path = selectedTaskPath else { return false }
        return snapshot?.tasks[path]?.value.status.isComplete == true
    }

    var canRescheduleSelectedTask: Bool {
        selectedTaskPath != nil && !selectedTaskIsComplete
    }

    var capturePrompt: String {
        switch quickCaptureRoute {
        case .today: "Capture for Today"
        case .upcoming: "Capture for Tomorrow"
        case .next, .waiting, .someday: "Capture to \(quickCaptureRoute.title)"
        case let .project(path): "Capture in \(projectDisplayTitle(path))"
        case let .area(path): "Capture in \(areaDisplayTitle(path))"
        default: "Capture to Inbox"
        }
    }

    func capturedTask(at path: VaultPath, title: String, route: WorkspaceRoute, now: Date) throws -> TodoTask {
        let today = try CalendarDate(date: now, calendar: vaultCalendar)
        let defaults = try TaskCaptureDefaults(route: route, today: today, calendar: vaultCalendar)
        return try TodoTask(
            path: path,
            title: title,
            status: defaults.status,
            priority: defaults.priority,
            scheduled: defaults.scheduled,
            project: defaults.project,
            area: defaults.area,
            tags: defaults.tags,
            createdAt: now,
            updatedAt: now
        )
    }

    func completeSelectedTask() async {
        guard let path = selectedTaskPath, let revision = snapshot?.tasks[path]?.revision else { return }
        await completeTask(at: path, expectedRevision: revision, vaultSession: vaultSession)
    }

    func beginRescheduling() {
        guard let path = selectedTaskPath, let task = snapshot?.tasks[path]?.value else { return }
        rescheduleSelection = RescheduleSelection(
            path: path,
            session: vaultSession,
            initialDate: task.scheduled?.description ?? task.deadline?
                .description ?? ""
        )
    }

    @discardableResult
    func rescheduleTask(at path: VaultPath, to date: CalendarDate, session: UUID, now: Date? = nil) -> Bool {
        guard session == vaultSession, let record = snapshot?.tasks[path] else { return false }
        let draft = taskDrafts[path] ?? makeDraft(record: record)
        taskDrafts[path] = draft
        guard !draft.hasConflicts, draft.sourceUnavailableMessage == nil else {
            errorMessage = "Resolve the task’s file changes before rescheduling it."
            return false
        }
        do {
            let now = now ?? clock()
            let current = try draft.patch().applying(to: draft.sourceTask, now: now)
            let updated = try TaskTransition.reschedule(current, to: date, now: now, calendar: vaultCalendar)
            guard updated != current else { return true }
            draft.isPlanningTransition = true
            undoManager?.beginUndoGrouping()
            defer { undoManager?.endUndoGrouping() }
            changeDraft(
                draft,
                keyPath: \.scheduled,
                to: updated.scheduled?.description ?? "",
                actionName: "Reschedule Task"
            )
            changeDraft(
                draft,
                keyPath: \.deadline,
                to: updated.deadline?.description ?? "",
                actionName: "Reschedule Task"
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rescheduleSelectedTask(daysFromToday days: Int, now: Date? = nil) {
        guard let path = selectedTaskPath else { return }
        do {
            let now = now ?? clock()
            let today = try CalendarDate(date: now, calendar: vaultCalendar)
            let date = try today.adding(DateComponents(day: days), calendar: vaultCalendar)
            rescheduleTask(at: path, to: date, session: vaultSession, now: now)
        } catch { errorMessage = error.localizedDescription }
    }
}

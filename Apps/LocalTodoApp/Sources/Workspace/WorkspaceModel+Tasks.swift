import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    var visibleTasks: [TodoTask] {
        guard let snapshot, let today = try? today(configuration: snapshot.configuration) else {
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
            text: searchText,
            includeCompleted: route == .all
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

    func createTask(title: String, vaultSession intentSession: UUID) async {
        guard intentSession == vaultSession, let store, let snapshot else { return }
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
            _ = try await store.create(.task(task))
            isQuickCapturePresented = false
            await refresh()
            selectTask(path)
        } catch {
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
            errorMessage = "The task changed before completion. Reload and try again."
            return
        }
        do {
            let now = Date()
            let task = record.value
            let updated = task.status.isComplete
                ? try TaskTransition.reopen(task, status: .next, now: now)
                : try TaskTransition.complete(
                    task,
                    now: now,
                    today: today(configuration: snapshot.configuration, now: now),
                    calendar: calendar(configuration: snapshot.configuration)
                )
            _ = try await store.update(.task(updated), expectedRevision: record.revision)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ draft: TaskDraft) async {
        guard draft.vaultSession == vaultSession, let store, let saveGeneration = draft.beginSaving() else { return }
        do {
            let patch = try draft.patch()
            let updated = try patch.applying(to: draft.sourceTask, now: Date())
            let record = try await store.update(.task(updated), expectedRevision: draft.revision)
            guard case let .task(savedTask) = record.value else { return }
            draft.acceptSave(
                VaultRecord(value: savedTask, revision: record.revision),
                generation: saveGeneration
            )
            await refresh()
        } catch {
            draft.finishSaving()
            errorMessage = error.localizedDescription
        }
    }

    private func nextTaskPath(title: String, snapshot: VaultSnapshot) throws -> VaultPath {
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

    private func today(configuration: VaultConfiguration, now: Date = Date()) throws -> CalendarDate {
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

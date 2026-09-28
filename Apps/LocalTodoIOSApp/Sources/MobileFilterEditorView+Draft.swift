import LocalTodoDomain
import LocalTodoWorkspace
import SwiftUI

extension MobileFilterEditorView {
    func save() async {
        do {
            var filters = TaskFilters()
            filters.statuses = statuses
            filters.priorities = priorities
            filters.includesNoPriority = includesNoPriority
            filters.project = projectPath.isEmpty ? nil : try VaultPath(projectPath)
            filters.area = areaPath.isEmpty ? nil : try VaultPath(areaPath)
            filters.tags = Set(tagsText.split(whereSeparator: \.isNewline).map(String.init))
            filters.scheduled = try DateRange(
                start: optionalDate(scheduledFrom), end: optionalDate(scheduledThrough)
            )
            filters.deadline = try DateRange(
                start: optionalDate(deadlineFrom), end: optionalDate(deadlineThrough)
            )
            let query = TaskQuery(
                scope: view.scope, text: text, filters: filters, includeCompleted: includeCompleted, sort: sort
            )
            let filter = try SavedTaskFilter(name: name, query: query)
            switch await workspace.saveFilter(filter, replacing: originalName) {
            case .saved:
                isFinished = true
                await discardCheckpoint()
                dismiss()
            case .conflict:
                pendingConflictFilter = filter
            case .failed:
                break
            }
        } catch {
            workspace.errorMessage = error.localizedDescription
        }
    }

    func delete() async {
        guard let originalName else { return }
        if await workspace.deleteFilter(named: originalName) {
            isFinished = true
            await discardCheckpoint()
            dismiss()
        }
    }

    func optionalDate(_ value: String) throws -> CalendarDate? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : try CalendarDate(trimmed)
    }

    var projects: [Project] {
        workspace.snapshot?.projects.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    var areas: [Area] {
        workspace.snapshot?.areas.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    func setBinding<Value: Hashable>(_ value: Value, in set: Binding<Set<Value>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { enabled in
                if enabled {
                    set.wrappedValue.insert(value)
                } else {
                    set.wrappedValue.remove(value)
                }
            }
        )
    }

    var editorKey: String {
        originalName.map { "existing:\($0)" } ?? "new"
    }

    var draftFingerprint: String {
        [
            name, view.rawValue, text, String(includeCompleted), sort.rawValue,
            statuses.map(\.rawValue).sorted().joined(separator: ","),
            priorities.map(\.rawValue).sorted().joined(separator: ","),
            String(includesNoPriority), projectPath, areaPath, tagsText,
            scheduledFrom, scheduledThrough, deadlineFrom, deadlineThrough,
        ].joined(separator: "\u{1f}")
    }

    func checkpointIfNeeded() async {
        guard didFinishLoading, !isFinished, draftFingerprint != baselineFingerprint,
              let identifier = workspace.vaultIdentifier else { return }
        checkpointGeneration += 1
        let checkpoint = FilterDraftCheckpoint(
            vaultIdentifier: identifier,
            editorKey: editorKey,
            originalName: originalName,
            baseRevision: baseRevision,
            generation: checkpointGeneration,
            name: name,
            view: view,
            text: text,
            includeCompleted: includeCompleted,
            sort: sort,
            statuses: statuses,
            priorities: priorities,
            includesNoPriority: includesNoPriority,
            projectPath: projectPath,
            areaPath: areaPath,
            tagsText: tagsText,
            scheduledFrom: scheduledFrom,
            scheduledThrough: scheduledThrough,
            deadlineFrom: deadlineFrom,
            deadlineThrough: deadlineThrough
        )
        do {
            try await workspace.filterCheckpoints.save(checkpoint)
        } catch {
            workspace.errorMessage = "The filter recovery draft could not be saved. \(error.localizedDescription)"
        }
    }

    func loadCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier,
              let checkpoint = try? await workspace.filterCheckpoints.checkpoints().first(where: {
                  $0.vaultIdentifier == identifier && $0.editorKey == editorKey
              }) else { return }
        checkpointGeneration = checkpoint.generation
        if checkpoint.baseRevision == workspace.session.savedFilters.revision?.value {
            apply(checkpoint)
            recoveredDraft = true
        } else {
            pendingCheckpoint = checkpoint
        }
    }

    func applyPendingCheckpoint() {
        guard let pendingCheckpoint else { return }
        apply(pendingCheckpoint)
        baseRevision = workspace.session.savedFilters.revision?.value
        recoveredDraft = true
        self.pendingCheckpoint = nil
    }

    func apply(_ checkpoint: FilterDraftCheckpoint) {
        name = checkpoint.name
        view = checkpoint.view
        text = checkpoint.text
        includeCompleted = checkpoint.includeCompleted
        sort = checkpoint.sort
        statuses = checkpoint.statuses
        priorities = checkpoint.priorities
        includesNoPriority = checkpoint.includesNoPriority
        projectPath = checkpoint.projectPath
        areaPath = checkpoint.areaPath
        tagsText = checkpoint.tagsText
        scheduledFrom = checkpoint.scheduledFrom
        scheduledThrough = checkpoint.scheduledThrough
        deadlineFrom = checkpoint.deadlineFrom
        deadlineThrough = checkpoint.deadlineThrough
    }

    func discardCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier else { return }
        try? await workspace.filterCheckpoints.remove(
            vaultIdentifier: identifier,
            editorKey: editorKey,
            through: checkpointGeneration
        )
        recoveredDraft = false
        pendingCheckpoint = nil
    }
}

import LocalTodoDomain
import SwiftUI

struct TaskRow: View {
    let model: WorkspaceModel
    let task: TodoTask
    let displayOptions: TaskListDisplayOptions
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Button {
                guard let revision = model.snapshot?.tasks[task.path]?.revision else { return }
                let vaultSession = model.vaultSession
                Task {
                    await model.completeTask(
                        at: task.path,
                        expectedRevision: revision,
                        vaultSession: vaultSession
                    )
                }
            } label: {
                Image(systemName: completionImage)
            }
            .buttonStyle(.plain)
            .foregroundStyle(priorityColor)
            .accessibilityLabel(task.status.isComplete ? "Reopen task" : "Mark complete")

            if model.inlineTitleEditingPath == task.path || model.isCustomTaskOrder {
                // Leave mouse tracking to the native List so a press can become a reorder drag.
                taskLabel
            } else {
                Button(action: onSelect) { taskLabel }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(task.title)")
                    .accessibilityHint(overdue.explanation)
            }
        }
        .padding(.vertical, 6)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(TaskAssignmentDrag(model: model, task: task))
        .contextMenu {
            Button("Edit Task") { model.editTask(at: task.path) }
            Button("Reschedule…") {
                model.selectTask(task.path)
                model.beginRescheduling()
            }
            .disabled(task.status.isComplete)
            Divider()
            TaskContextActions(model: model, path: task.path)
        }
    }

    private var completionImage: String {
        switch task.status {
        case .done: "checkmark.circle.fill"
        case .canceled: "xmark.circle.fill"
        default: "circle"
        }
    }

    private var taskLabel: some View {
        VStack(
            alignment: .leading,
            spacing: model.effectiveAppearance.number("--row-spacing", scheme: colorScheme, fallback: 3)
        ) {
            if model.inlineTitleEditingPath == task.path, let draft = model.taskDrafts[task.path] {
                InlineTaskTitleEditor(model: model, draft: draft)
                    .themeFont(.body)
            } else {
                titleLabel
            }
            if hasMetadata {
                metadata
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 10)
        .contentShape(Rectangle())
    }

    private var titleLabel: some View {
        Text(TaskMarkdown.inline(task.title, links: false))
            .themeFont(.body)
            .strikethrough(task.status.isComplete)
            .foregroundStyle(overdue.isOverdue ? Color.red : Color.primary)
            .contentShape(Rectangle())
            .background(TaskTitleDoubleClick {
                model.beginInlineTitleEditing(at: task.path)
            })
            .accessibilityAction(named: "Edit Title Inline") {
                model.beginInlineTitleEditing(at: task.path)
            }
    }

    private var overdue: TaskOverdueState {
        TaskOverdueState(task: task, today: try? CalendarDate(date: model.clock(), calendar: model.vaultCalendar))
    }

    private var priorityColor: Color {
        guard !task.status.isComplete else { return .secondary }
        switch task.priority {
        case .p1: return model.effectiveAppearance.color("--priority-1", scheme: colorScheme, fallback: .red)
        case .p2: return model.effectiveAppearance.color("--priority-2", scheme: colorScheme, fallback: .orange)
        case .p3: return model.effectiveAppearance.color("--priority-3", scheme: colorScheme, fallback: .blue)
        default: return .primary
        }
    }
}

private extension TaskRow {
    var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                planningMetadata
                organizationMetadata
                tagsMetadata
            }
            VStack(alignment: .leading, spacing: 2) {
                if hasPlanningMetadata {
                    planningMetadata
                }
                if hasOrganizationMetadata {
                    organizationMetadata
                }
                tagsMetadata
            }
        }
        .themeFont(.caption)
        .foregroundStyle(.secondary)
    }

    private var planningMetadata: some View {
        HStack(spacing: 8) {
            if overdue.isOverdue {
                Label("Overdue", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .help(overdue.explanation)
            }
            if let priority = task.priority {
                Text(priority.rawValue.uppercased())
                    .foregroundStyle(priorityColor)
                    .accessibilityLabel("Priority \(priority.rawValue.uppercased())")
            }
            if showsScheduledDate, let scheduled = task.scheduled {
                Label(
                    model.preferences.dateFormat.string(scheduled, calendar: model.vaultCalendar),
                    systemImage: "calendar"
                )
                .foregroundStyle(overdue.scheduled ? Color.red : Color.secondary)
            }
            if let deadline = task.deadline {
                Label(model.preferences.dateFormat.string(deadline, calendar: model.vaultCalendar), systemImage: "flag")
                    .foregroundStyle(overdue.deadline ? Color.red : Color.secondary)
            }
            if task.recurrence != nil {
                Label("Repeats", systemImage: "repeat")
            }
        }
    }

    private var organizationMetadata: some View {
        HStack(spacing: 8) {
            if showsProject, let project = task.project {
                projectLabel(project)
            }
            if showsArea, let area = task.area {
                areaLabel(area)
            }
        }
    }

    @ViewBuilder
    private var tagsMetadata: some View {
        if displayOptions.showsTags, !task.tags.isEmpty {
            let tags = task.tags.map { "#\($0)" }.joined(separator: " ")
            Label(tags, systemImage: "tag")
                .lineLimit(1)
                .help(tags)
        }
    }

    private var hasPlanningMetadata: Bool {
        task.priority != nil || showsScheduledDate || task.deadline != nil || task.recurrence != nil
    }

    private var showsScheduledDate: Bool {
        TaskListDisplayOptions.showsScheduledDate(
            task.scheduled,
            route: model.route,
            today: try? CalendarDate(date: model.clock(), calendar: model.vaultCalendar)
        )
    }

    private var hasMetadata: Bool {
        hasPlanningMetadata || hasOrganizationMetadata || displayOptions.showsTags && !task.tags.isEmpty
    }

    private var hasOrganizationMetadata: Bool {
        showsProject && task.project != nil
            || showsArea && task.area != nil
    }

    private var showsProject: Bool {
        displayOptions.showsProject && displayOptions.grouping != .project
    }

    private var showsArea: Bool {
        displayOptions.showsArea && displayOptions.grouping != .area
    }

    @ViewBuilder
    private func projectLabel(_ path: VaultPath) -> some View {
        if let project = model.snapshot?.projects[path]?.value {
            Label(model.projectDisplayTitle(project.path), systemImage: "square.stack")
        } else {
            Label("Missing project: \(fallbackTitle(path))", systemImage: "exclamationmark.triangle")
                .help(path.value)
        }
    }

    @ViewBuilder
    private func areaLabel(_ path: VaultPath) -> some View {
        if let area = model.snapshot?.areas[path]?.value {
            Label(model.areaDisplayTitle(area.path), systemImage: "circle.grid.2x2")
        } else {
            Label("Missing area: \(fallbackTitle(path))", systemImage: "exclamationmark.triangle")
                .help(path.value)
        }
    }

    private func fallbackTitle(_ path: VaultPath) -> String {
        let filename = path.value.split(separator: "/").last.map(String.init) ?? path.value
        return filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
    }
}

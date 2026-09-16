import LocalTodoDomain
import SwiftUI

struct TaskRow: View {
    let model: WorkspaceModel
    let task: TodoTask
    let displayOptions: TaskListDisplayOptions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
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
            .accessibilityLabel(task.status.isComplete ? "Reopen task" : "Mark complete")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.status.isComplete)
                metadata
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { model.editTask(at: task.path) }
        }
        .draggable(TaskDragItem(path: task.path.value, vaultSession: model.vaultSession)) {
            Label(task.title, systemImage: "checklist")
                .padding(8)
        }
        .contextMenu {
            Button("Edit Task") { model.editTask(at: task.path) }
            Button("Reschedule…") {
                model.selectTask(task.path)
                model.beginRescheduling()
            }
            .disabled(task.status.isComplete)
        }
    }

    private var completionImage: String {
        switch task.status {
        case .done: "checkmark.circle.fill"
        case .canceled: "xmark.circle.fill"
        default: "circle"
        }
    }

    private var metadata: some View {
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
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var planningMetadata: some View {
        HStack(spacing: 8) {
            if let priority = task.priority {
                Text(priority.rawValue.uppercased())
            }
            if let scheduled = task.scheduled {
                Label(scheduled.description, systemImage: "calendar")
            }
            if let deadline = task.deadline {
                Label(deadline.description, systemImage: "flag")
            }
        }
    }

    private var organizationMetadata: some View {
        HStack(spacing: 8) {
            if displayOptions.showsProject, let project = task.project {
                projectLabel(project)
            }
            if displayOptions.showsArea, let area = task.area {
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
        task.priority != nil || task.scheduled != nil || task.deadline != nil
    }

    private var hasOrganizationMetadata: Bool {
        displayOptions.showsProject && task.project != nil
            || displayOptions.showsArea && task.area != nil
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

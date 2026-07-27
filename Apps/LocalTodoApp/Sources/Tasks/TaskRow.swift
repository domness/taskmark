import LocalTodoDomain
import SwiftUI

struct TaskRow: View {
    let model: WorkspaceModel
    let task: TodoTask

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
                    if let project = task.project {
                        Text(project.value.split(separator: "/").last.map(String.init) ?? project.value)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var completionImage: String {
        switch task.status {
        case .done: "checkmark.circle.fill"
        case .canceled: "xmark.circle.fill"
        default: "circle"
        }
    }
}

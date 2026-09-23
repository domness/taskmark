import LocalTodoDomain
import SwiftUI

struct TaskInspectorHeader: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft
    @Binding var isTitleEditing: Bool
    @State private var isCompleting = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                guard let revision = model.snapshot?.tasks[draft.path]?.revision else { return }
                let session = model.vaultSession
                isCompleting = true
                Task {
                    defer { isCompleting = false }
                    await model.completeTask(at: draft.path, expectedRevision: revision, vaultSession: session)
                }
            } label: {
                Image(systemName: completionImage)
                    .themeFont(.body)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(completionColor)
            .disabled(isCompleting)
            .accessibilityLabel(draft.status.isComplete ? "Reopen task" : "Mark complete")
            .accessibilityIdentifier("inspector-completion")
            .help(draft.status.isComplete ? "Reopen task" : "Mark complete")

            TaskMarkdownField(text: $draft.title, kind: .title, subject: "Task", isEditing: $isTitleEditing)
        }
    }

    private var completionImage: String {
        switch draft.status {
        case .done: "checkmark.circle.fill"
        case .canceled: "xmark.circle.fill"
        default: "circle"
        }
    }

    private var completionColor: Color {
        guard !draft.status.isComplete else { return .secondary }
        switch draft.priority {
        case .p1: return model.effectiveAppearance.color("--priority-1", scheme: colorScheme, fallback: .red)
        case .p2: return model.effectiveAppearance.color("--priority-2", scheme: colorScheme, fallback: .orange)
        case .p3: return model.effectiveAppearance.color("--priority-3", scheme: colorScheme, fallback: .blue)
        default: return .primary
        }
    }
}

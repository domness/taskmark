import LocalTodoDomain
import SwiftUI

struct TaskInspectorHeader: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft
    @Binding var isTitleEditing: Bool
    @State private var isPerformingCompletionAction = false
    @State private var showsCompletionFeedback = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                toggleCompletion()
            } label: {
                TaskCompletionIcon(status: draft.status, showsCompletionFeedback: showsCompletionFeedback)
                    .themeFont(.body)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(showsCompletionFeedback ? Color.green : completionColor)
            .disabled(isPerformingCompletionAction)
            .accessibilityLabel(completionAccessibilityLabel)
            .accessibilityIdentifier("inspector-completion")
            .help(draft.status.isComplete ? "Reopen task" : "Mark complete")

            TaskMarkdownField(text: $draft.title, kind: .title, subject: "Task", isEditing: $isTitleEditing)
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

    private var completionAccessibilityLabel: String {
        if showsCompletionFeedback {
            return "Task completed"
        }
        return draft.status.isComplete ? "Reopen task" : "Mark complete"
    }

    private func toggleCompletion() {
        guard !isPerformingCompletionAction else { return }
        let session = model.vaultSession
        let isMarkingComplete = !draft.status.isComplete
        isPerformingCompletionAction = true
        showsCompletionFeedback = isMarkingComplete
        Task {
            if isMarkingComplete {
                try? await Task.sleep(for: .milliseconds(180))
            }
            guard let revision = model.snapshot?.tasks[draft.path]?.revision else {
                showsCompletionFeedback = false
                isPerformingCompletionAction = false
                return
            }
            let succeeded = await model.completeTask(
                at: draft.path,
                expectedRevision: revision,
                vaultSession: session
            )
            if succeeded, isMarkingComplete {
                try? await Task.sleep(for: .milliseconds(120))
            }
            showsCompletionFeedback = false
            isPerformingCompletionAction = false
        }
    }
}

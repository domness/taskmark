import SwiftUI

struct InlineTaskTitleEditor: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Task title", text: Binding(
            get: { draft.title },
            set: { model.changeDraft(draft, keyPath: \.title, to: $0, actionName: "Edit Title") }
        ), onEditingChanged: { editing in
            if !editing {
                model.finishInlineTitleEditing(draft)
            }
        })
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("inline-task-title")
        .background(MarkdownEditingBoundary {
            model.finishInlineTitleEditing(draft)
        })
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onSubmit { model.finishInlineTitleEditing(draft) }
        .onChange(of: model.selectedTaskPath) { _, path in
            if path != draft.path {
                model.finishInlineTitleEditing(draft)
            }
        }
        .onChange(of: model.route) { _, _ in model.finishInlineTitleEditing(draft) }
        .onDisappear { model.finishInlineTitleEditing(draft) }
    }
}

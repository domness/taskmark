import SwiftUI

struct TaskTabView: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft

    var body: some View {
        ScrollView {
            TaskContentFields(model: model, draft: draft, startsNotesEditing: true)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .themeSurface()
        .disabled(model.deletingTaskPaths.contains(draft.path))
    }
}

struct TaskTabOptionsView: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft

    var body: some View {
        ScrollView {
            TaskInspectorOptions(model: model, draft: draft)
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .disabled(model.deletingTaskPaths.contains(draft.path))
    }
}

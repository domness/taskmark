import SwiftUI

struct InspectorContentView: View {
    let model: WorkspaceModel

    var body: some View {
        inspector
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themeSurface("--inspector-background")
    }

    @ViewBuilder
    private var inspector: some View {
        if let draft = model.selectedTaskDraft {
            TaskInspectorView(model: model, draft: draft)
                .id(draft.path)
        } else if let draft = model.selectedProjectDraft {
            ProjectInspectorView(model: model, draft: draft)
                .id(draft.path)
        } else {
            ContentUnavailableView(
                "No Task Selected",
                systemImage: "checkmark.circle",
                description: Text("Select a task to inspect its metadata and notes.")
            )
        }
    }
}

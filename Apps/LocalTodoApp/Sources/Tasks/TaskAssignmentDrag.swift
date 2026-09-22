import LocalTodoDomain
import SwiftUI

/// Native list moves and transferable drags compete for the same row gesture.
struct TaskAssignmentDrag: ViewModifier {
    let model: WorkspaceModel
    let task: TodoTask

    func body(content: Content) -> some View {
        if model.isCustomTaskOrder {
            content
        } else {
            content.draggable(TaskDragItem(path: task.path.value, vaultSession: model.vaultSession)) {
                Label(task.title, systemImage: "checklist").padding(8)
            }
        }
    }
}

/// A separate hit region keeps Custom-order row dragging owned by the native List.
struct TaskAssignmentHandle: View {
    let model: WorkspaceModel
    let task: TodoTask

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .foregroundStyle(.secondary)
            .padding(6)
            .contentShape(Rectangle())
            .draggable(TaskDragItem(path: task.path.value, vaultSession: model.vaultSession)) {
                Label(task.title, systemImage: "checklist").padding(8)
            }
            .help("Drag to a sidebar project, area or tag. Drag the title to reorder.")
            .accessibilityLabel("Organize \(task.title)")
            .accessibilityHint("Drag to a project, area or tag, or use task details")
            .accessibilityAction(named: "Edit Organization") { model.editTask(at: task.path) }
    }
}

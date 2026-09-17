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

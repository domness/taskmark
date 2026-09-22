import LocalTodoDomain
import SwiftUI
import UniformTypeIdentifiers

/// One native row source serves both sidebar assignment and Custom-order insertion.
struct TaskAssignmentDrag: ViewModifier {
    let model: WorkspaceModel
    let task: TodoTask
    let context: TaskReorderContext

    func body(content: Content) -> some View {
        content.onDrag {
            TaskDragItem(
                path: task.path.value,
                vaultSession: model.vaultSession,
                reorder: model.isCustomTaskOrder ? TaskDragOrder(context: context) : nil
            ).itemProvider()
        } preview: {
            Label(task.title, systemImage: "checklist").padding(8)
        }
    }
}

extension TaskDragItem {
    func itemProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.localTodoTaskReference.identifier,
            visibility: .ownProcess
        ) { completion in
            do {
                try completion(JSONEncoder().encode(self), nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        return provider
    }
}

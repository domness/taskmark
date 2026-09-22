import Foundation
import UniformTypeIdentifiers

extension WorkspaceModel {
    func insertDraggedTask(from providers: [NSItemProvider], at destination: Int, context: TaskReorderContext) {
        guard providers.count == 1, let provider = providers.first else { return }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.localTodoTaskReference.identifier) { data, _ in
            guard let data, let item = try? JSONDecoder().decode(TaskDragItem.self, from: data) else { return }
            Task { @MainActor in
                self.insertDraggedTask(item, at: destination, context: context)
            }
        }
    }

    @discardableResult
    func insertDraggedTask(_ item: TaskDragItem, at destination: Int, context: TaskReorderContext) -> Bool {
        guard item.vaultSession == context.session, item.reorder?.matches(context) == true,
              let index = context.sectionPaths.firstIndex(where: { $0.value == item.path }) else { return false }
        return moveTasks(from: IndexSet(integer: index), to: destination, context: context)
    }
}

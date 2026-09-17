import LocalTodoDomain
import SwiftUI

struct TaskSortPicker: View {
    let model: WorkspaceModel

    var body: some View {
        Picker("Sort", selection: Binding(
            get: { model.currentTaskListSort }, set: { model.setTaskListSort($0) }
        )) {
            Text("Custom").tag(TaskListSort.custom)
            ForEach(TaskSort.allCases, id: \.self) { Text($0.title).tag(TaskListSort.automatic($0)) }
        }
    }
}

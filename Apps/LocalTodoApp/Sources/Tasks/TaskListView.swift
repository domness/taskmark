import LocalTodoDomain
import SwiftUI

struct TaskListView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            if model.isQuickCapturePresented {
                QuickCaptureRow(model: model)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
            }
            if model.visibleTasks.isEmpty {
                ContentUnavailableView(
                    model.searchText.isEmpty ? "No Tasks" : "No Results",
                    systemImage: model.searchText.isEmpty ? "checkmark.circle" : "magnifyingglass",
                    description: Text(model.searchText
                        .isEmpty ? "Capture a task or choose another view." : "Try a different search.")
                )
            } else {
                List(model.visibleTasks, id: \.path, selection: selection) { task in
                    TaskRow(model: model, task: task)
                        .tag(task.path)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(model.route.title)
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search tasks")
        .toolbar {
            ToolbarItemGroup {
                Button("New Task", systemImage: "plus") { model.beginQuickCapture() }
                    .help("New Task (Command-N)")
                Button("Toggle Inspector", systemImage: "sidebar.trailing") {
                    model.isInspectorPresented.toggle()
                }
                .help("Toggle Inspector")
            }
        }
    }

    private var selection: Binding<VaultPath?> {
        Binding(
            get: { model.selectedTaskPath },
            set: { model.selectTask($0) }
        )
    }
}

import LocalTodoDomain
import SwiftUI

struct TaskListView: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.isQuickCapturePresented {
                QuickCaptureRow(model: model)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
            }
            if model.route == .search, !model.hasActiveSearch {
                ContentUnavailableView(
                    "Search Tasks",
                    systemImage: "magnifyingglass",
                    description: Text("Search titles, notes, and tags across the vault.")
                )
            } else if model.visibleTasks.isEmpty {
                ContentUnavailableView(
                    model.route == .search ? "No Results" : "No Tasks",
                    systemImage: model.route == .search ? "magnifyingglass" : "checkmark.circle",
                    description: Text(
                        model.route == .search
                            ? "Try a different search."
                            : "Capture a task or choose another view."
                    )
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
        .searchFocused($isSearchFocused)
        .onChange(of: model.route) { _, route in
            isSearchFocused = route == .search
        }
        .onChange(of: model.searchText) { _, text in
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                model.route = .search
            }
        }
        .onAppear { isSearchFocused = model.route == .search }
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

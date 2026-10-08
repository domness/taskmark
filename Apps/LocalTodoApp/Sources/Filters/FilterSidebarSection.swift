import SwiftUI

struct FilterSidebarSection: View {
    let model: WorkspaceModel
    @State private var filterPendingDeletion: String?

    var body: some View {
        Section("Saved Filters") {
            ForEach(model.filterState.record?.filters ?? [], id: \.name) { filter in
                SidebarRouteLabel(
                    model: model, route: .savedFilter(filter.name), title: filter.name,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .tag(WorkspaceRoute.savedFilter(filter.name))
                .contextMenu {
                    Button("Delete Filter", systemImage: "trash", role: .destructive) {
                        filterPendingDeletion = filter.name
                    }
                }
            }
            Button("New Filter", systemImage: "plus") { model.beginFilterEditing() }
            if model.filterState.loadError != nil {
                Label("Saved filters unavailable", systemImage: "exclamationmark.triangle")
                Button("Reload Filters") { Task { await model.refreshSavedFilters() } }
            }
        }
        .confirmationDialog(
            "Delete \(filterPendingDeletion ?? "this filter")?",
            isPresented: Binding(
                get: { filterPendingDeletion != nil },
                set: {
                    if !$0 {
                        filterPendingDeletion = nil
                    }
                }
            )
        ) {
            Button("Delete Filter", role: .destructive) {
                guard let name = filterPendingDeletion else { return }
                filterPendingDeletion = nil
                Task { await model.deleteSavedFilter(named: name) }
            }
            Button("Cancel", role: .cancel) { filterPendingDeletion = nil }
        } message: {
            Text("The saved filter will be removed. Its tasks will not be changed.")
        }
    }
}

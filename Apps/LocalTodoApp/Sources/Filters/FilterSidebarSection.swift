import SwiftUI

struct FilterSidebarSection: View {
    let model: WorkspaceModel

    var body: some View {
        Section("Saved Filters") {
            ForEach(model.filterState.record?.filters ?? [], id: \.name) { filter in
                SidebarRouteLabel(
                    model: model, route: .savedFilter(filter.name), title: filter.name,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .tag(WorkspaceRoute.savedFilter(filter.name))
            }
            Button("New Filter", systemImage: "plus") { model.beginFilterEditing() }
            if model.filterState.loadError != nil {
                Label("Saved filters unavailable", systemImage: "exclamationmark.triangle")
                Button("Reload Filters") { Task { await model.refreshSavedFilters() } }
            }
        }
    }
}

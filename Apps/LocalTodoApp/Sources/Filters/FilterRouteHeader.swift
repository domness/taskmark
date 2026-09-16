import SwiftUI

struct FilterRouteHeader: View {
    let model: WorkspaceModel

    var body: some View {
        if model.route == .filters {
            FilterEditorView(model: model, state: model.filterState)
            Divider()
        } else if case let .savedFilter(name) = model.route {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Button("Edit Filter") { model.beginFilterEditing(name: name) }
            }
            .padding(12)
            if let message = model.filterState.loadError ?? model.filterState.saveError {
                Label(message, systemImage: "exclamationmark.triangle").padding(.horizontal, 12)
            } else if model.currentTaskQuery == nil {
                Text("This saved filter is no longer in the vault.").padding(.horizontal, 12)
            }
            Divider()
        }
        if let message = model.filterReferenceMessage {
            Label(message, systemImage: "exclamationmark.triangle").padding(12)
        }
    }
}

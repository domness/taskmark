import SwiftUI

struct FilterRouteHeader: View {
    let model: WorkspaceModel
    @State private var filterPendingDeletion: String?

    var body: some View {
        Group {
            if model.route == .filters {
                FilterEditorView(model: model, state: model.filterState)
                Divider()
            } else if case let .savedFilter(name) = model.route {
                HStack {
                    Text(name).themeFont(.headline)
                    Spacer()
                    Button("Edit Filter") { model.beginFilterEditing(name: name) }
                    Button("Delete Filter", systemImage: "trash", role: .destructive) {
                        filterPendingDeletion = name
                    }
                    .labelStyle(.iconOnly)
                    .help("Delete filter")
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

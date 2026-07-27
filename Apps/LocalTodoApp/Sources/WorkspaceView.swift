import SwiftUI

struct WorkspaceView: View {
    private let primaryViews = ["Inbox", "Today", "Next"]

    var body: some View {
        NavigationSplitView {
            List {
                Section("Focus") {
                    ForEach(primaryViews, id: \.self) { name in
                        Label(name, systemImage: icon(for: name))
                    }
                }

                Section("Organize") {
                    Label("Projects", systemImage: "square.stack")
                    Label("Areas", systemImage: "circle.grid.2x2")
                    Label("Tags", systemImage: "tag")
                }
            }
            .navigationTitle("Local Todo")
        } content: {
            ContentUnavailableView(
                "Choose a Vault",
                systemImage: "folder",
                description: Text("Select a folder containing .localtodo/config.yml to begin.")
            )
            .navigationTitle("Today")
        } detail: {
            ContentUnavailableView(
                "No Task Selected",
                systemImage: "checkmark.circle",
                description: Text("Task details will appear here.")
            )
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 840, minHeight: 560)
    }

    private func icon(for name: String) -> String {
        switch name {
        case "Inbox": "tray"
        case "Today": "sun.max"
        case "Next": "arrow.right.circle"
        default: "circle"
        }
    }
}

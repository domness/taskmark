import LocalTodoDomain
import SwiftUI

struct SidebarView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        List(selection: $model.route) {
            Section("Focus") {
                route(.today, "Today", "sun.max")
                route(.inbox, "Inbox", "tray")
                route(.next, "Next", "arrow.right.circle")
                route(.all, "All Tasks", "checklist")
                route(.search, "Search", "magnifyingglass")
            }
            if let snapshot = model.snapshot {
                Section("Projects") {
                    ForEach(snapshot.projects.keys.sorted(by: { $0.value < $1.value }), id: \.self) { path in
                        route(.project(path), snapshot.projects[path]?.value.title ?? path.value, "square.stack")
                    }
                    Button("New Project", systemImage: "plus") { model.newEntityKind = .project }
                }
                Section("Areas") {
                    ForEach(snapshot.areas.keys.sorted(by: { $0.value < $1.value }), id: \.self) { path in
                        route(.area(path), snapshot.areas[path]?.value.title ?? path.value, "circle.grid.2x2")
                    }
                    Button("New Area", systemImage: "plus") { model.newEntityKind = .area }
                }
                if !model.allTags.isEmpty {
                    Section("Tags") {
                        ForEach(model.allTags, id: \.self) { tag in
                            route(.tag(tag), tag, "tag")
                        }
                    }
                }
                Section("Priorities") {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        route(.priority(priority), priority.rawValue.uppercased(), "exclamationmark")
                    }
                    route(.priority(nil), "No Priority", "minus")
                }
                if !snapshot.diagnostics.isEmpty {
                    Section {
                        route(.issues, "Issues (\(snapshot.diagnostics.count))", "exclamationmark.triangle")
                    }
                }
            }
        }
        .navigationTitle(model.vaultName ?? "Local Todo")
        .safeAreaInset(edge: .bottom) {
            Button("Switch Vault", systemImage: "folder") { Task { await model.chooseVault() } }
                .buttonStyle(.plain)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func route(_ route: WorkspaceRoute, _ title: String, _ image: String) -> some View {
        Label(title, systemImage: image).tag(route)
    }
}

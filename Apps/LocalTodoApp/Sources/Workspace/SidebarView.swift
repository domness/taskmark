import LocalTodoDomain
import SwiftUI

struct SidebarView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            navigationList
            Divider()
            Button("Switch Vault", systemImage: "folder") { Task { await model.chooseVault() } }
                .buttonStyle(.plain)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(model.vaultName ?? "Local Todo")
    }

    private var navigationList: some View {
        List(selection: $model.route) {
            Section("Focus") {
                route(.today, "Today", "sun.max")
                route(.inbox, "Inbox", "tray")
                route(.next, "Next", "arrow.right.circle")
                route(.upcoming, "Upcoming", "calendar")
                route(.waiting, "Waiting", "hourglass")
                route(.someday, "Someday", "archivebox")
                route(.all, "All Tasks", "checklist")
                route(.search, "Search", "magnifyingglass")
            }
            if let snapshot = model.snapshot {
                FilterSidebarSection(model: model)
                ProjectSidebarSection(model: model)
                Section("Areas") {
                    ForEach(model.orderedCollectionPaths(.area), id: \.self) { path in
                        SidebarAssignmentRoute(
                            model: model,
                            route: .area(path),
                            title: model.areaDisplayTitle(path),
                            systemImage: "circle.grid.2x2",
                            target: .area(path)
                        )
                        .contextMenu {
                            CollectionOrderActions(model: model, path: path, collection: .area)
                        }
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
    }

    private func route(_ route: WorkspaceRoute, _ title: String, _ image: String) -> some View {
        Label(title, systemImage: image).tag(route)
    }
}

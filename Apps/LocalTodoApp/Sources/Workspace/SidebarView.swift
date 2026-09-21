import LocalTodoDomain
import SwiftUI

struct SidebarView: View {
    @Bindable var model: WorkspaceModel
    @State private var showsTags = false
    @State private var showsPriorities = false

    var body: some View {
        VStack(spacing: 0) {
            navigationList
            Divider()
            Button("Switch Vault", systemImage: "folder") { Task { await model.chooseVault() } }
                .buttonStyle(.plain)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(model.vaultName ?? "Taskmark")
        .themeSurface("--sidebar-background")
    }

    private var navigationList: some View {
        let areas = model.orderedCollectionPaths(.area)
        let session = model.vaultSession
        return List(selection: $model.route) {
            Section("Focus") {
                route(.inbox, "Inbox", "tray")
                route(.today, "Today", "sun.max")
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
                    ForEach(areas, id: \.self) { path in
                        SidebarAssignmentRoute(
                            model: model,
                            route: .area(path),
                            title: model.areaDisplayTitle(path),
                            systemImage: "circle.grid.2x2",
                            target: .area(path)
                        )
                        .contextMenu {
                            CollectionOrderActions(model: model, path: path, collection: .area)
                            Divider()
                            Button("Delete Area", role: .destructive) {
                                Task { await model.deleteCollection(at: path) }
                            }
                        }
                    }
                    .onMove { offsets, destination in
                        _ = model.moveCollections(
                            from: offsets,
                            to: destination,
                            in: .area,
                            paths: areas,
                            session: session
                        )
                    }
                    Button("New Area", systemImage: "plus") { model.newEntityKind = .area }
                }
                if !model.allTags.isEmpty {
                    Section("Tags", isExpanded: $showsTags) {
                        ForEach(model.allTags, id: \.self) { tag in
                            route(.tag(tag), tag, "tag")
                        }
                    }
                }
                Section("Priorities", isExpanded: $showsPriorities) {
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
        .scrollContentBackground(.hidden)
    }

    private func route(_ route: WorkspaceRoute, _ title: String, _ image: String) -> some View {
        Label(title, systemImage: image).tag(route)
    }
}

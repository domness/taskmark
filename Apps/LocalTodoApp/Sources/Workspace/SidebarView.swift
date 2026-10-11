import LocalTodoDomain
import SwiftUI

struct SidebarView: View {
    @Bindable var model: WorkspaceModel
    var onNavigate: (WorkspaceRoute) -> Void = { _ in }
    var onOpenRouteInTab: (WorkspaceRoute) -> Void = { _ in }
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
        return List(selection: routeSelection) {
            Section("Focus") {
                focusRoute(.inbox, "Inbox", "tray", target: .inbox)
                focusRoute(.today, "Today", "sun.max", target: .today)
                focusRoute(.next, "Next", "arrow.right.circle", target: .next)
                focusRoute(.upcoming, "Upcoming", "calendar", target: .upcoming)
                focusRoute(.waiting, "Waiting", "hourglass", target: .waiting)
                focusRoute(.someday, "Someday", "archivebox", target: .someday)
                focusRoute(.completed, "Completed", "checkmark.circle", target: .completed)
                route(.all, "All Tasks", "checklist")
                route(.search, "Search", "magnifyingglass")
            }
            if let snapshot = model.snapshot {
                FilterSidebarSection(model: model, onOpenRouteInTab: onOpenRouteInTab)
                ProjectSidebarSection(model: model, onOpenRouteInTab: onOpenRouteInTab)
                Section("Areas") {
                    ForEach(areas, id: \.self) { path in
                        SidebarAssignmentRoute(
                            model: model,
                            route: .area(path),
                            title: model.areaDisplayTitle(path),
                            systemImage: "circle.grid.2x2",
                            target: .area(path),
                            onOpenInTab: { onOpenRouteInTab(.area(path)) }
                        )
                        .contextMenu {
                            Button("Open in New Tab") { onOpenRouteInTab(.area(path)) }
                            Divider()
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
                            SidebarAssignmentRoute(
                                model: model, route: .tag(tag), title: tag,
                                systemImage: "tag", target: .tag(tag),
                                onOpenInTab: { onOpenRouteInTab(.tag(tag)) }
                            )
                            .contextMenu {
                                Button("Open in New Tab") { onOpenRouteInTab(.tag(tag)) }
                                Divider()
                                Button("Delete Tag", role: .destructive) {
                                    Task { await model.deleteTag(tag) }
                                }
                            }
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
        .disableNativeListSelectionHighlight()
        .scrollContentBackground(.hidden)
    }

    private func route(_ route: WorkspaceRoute, _ title: String, _ image: String) -> some View {
        SidebarRouteLabel(
            model: model,
            route: route,
            title: title,
            systemImage: image,
            onOpenInTab: { onOpenRouteInTab(route) }
        )
        .tag(route)
        .contextMenu {
            Button("Open in New Tab") { onOpenRouteInTab(route) }
        }
    }

    private func focusRoute(
        _ route: WorkspaceRoute,
        _ title: String,
        _ image: String,
        target: FocusDropTarget
    ) -> some View {
        SidebarAssignmentRoute(
            model: model,
            route: route,
            title: title,
            systemImage: image,
            target: .focus(target),
            onOpenInTab: { onOpenRouteInTab(route) }
        )
        .contextMenu {
            Button("Open in New Tab") { onOpenRouteInTab(route) }
        }
    }

    private var routeSelection: Binding<WorkspaceRoute> {
        Binding(
            get: { model.route },
            set: { route in
                onNavigate(route)
                model.route = route
            }
        )
    }
}

import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import LocalTodoWorkspace
import SwiftUI

struct MobileWorkspaceView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let workspace: MobileWorkspace

    var body: some View {
        if horizontalSizeClass == .regular {
            TabletWorkspaceView(workspace: workspace)
        } else {
            CompactWorkspaceView(workspace: workspace)
        }
    }
}

private enum CompactTab: Hashable { case today, inbox, browse, search }

private struct CompactWorkspaceView: View {
    let workspace: MobileWorkspace
    @State private var tab: CompactTab

    init(workspace: MobileWorkspace) {
        self.workspace = workspace
        let initialTab: CompactTab = switch workspace.initialRoute {
        case .today: .today
        case .inbox: .inbox
        case .search: .search
        default: .browse
        }
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { MobileTaskListView(workspace: workspace, route: .today) }
                .tabItem { Label("Today", systemImage: "sun.max") }.tag(CompactTab.today)
            NavigationStack { MobileTaskListView(workspace: workspace, route: .inbox) }
                .tabItem { Label("Inbox", systemImage: "tray") }.tag(CompactTab.inbox)
            MobileBrowseView(workspace: workspace, initialRoute: workspace.initialRoute)
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }.tag(CompactTab.browse)
            NavigationStack {
                MobileTaskListView(workspace: workspace, route: .search)
                    .searchable(text: Bindable(workspace).searchText, prompt: "Tasks and notes")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(CompactTab.search)
        }
    }
}

private struct TabletWorkspaceView: View {
    let workspace: MobileWorkspace
    @State private var route: WorkspaceRoute?
    @State private var selectedPath: VaultPath?

    init(workspace: MobileWorkspace) {
        self.workspace = workspace
        _route = State(initialValue: workspace.initialRoute)
    }

    var body: some View {
        NavigationSplitView {
            MobileRouteList(workspace: workspace, selection: $route).navigationTitle("Taskmark")
        } content: {
            if let route {
                MobileTaskListView(workspace: workspace, route: route, selectedPath: $selectedPath)
            }
        } detail: {
            if let selectedPath {
                MobileTaskDetailView(workspace: workspace, path: selectedPath)
            } else {
                ContentUnavailableView("Select a Task", systemImage: "checklist")
            }
        }
    }
}

struct MobileBrowseView: View {
    let workspace: MobileWorkspace
    let initialRoute: WorkspaceRoute
    @State private var path: [WorkspaceRoute]

    init(workspace: MobileWorkspace, initialRoute: WorkspaceRoute = .all) {
        self.workspace = workspace
        self.initialRoute = initialRoute
        let builtIns: Set<WorkspaceRoute> = [.next, .upcoming, .waiting, .someday, .all]
        _path = State(initialValue: builtIns.contains(initialRoute) ? [initialRoute] : [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            MobileRouteList(workspace: workspace, selection: nil)
                .navigationTitle("Browse")
                .navigationDestination(for: WorkspaceRoute.self) { route in
                    MobileTaskListView(workspace: workspace, route: route)
                }
        }
    }
}

private struct MobileRouteList: View {
    let workspace: MobileWorkspace
    var selection: Binding<WorkspaceRoute?>?
    @State private var isCreatingCollection = false
    @State private var newCollectionKind: WorkspaceCollectionKind = .project
    @State private var isCreatingFilter = false
    private let builtIns: [WorkspaceRoute] = [.next, .upcoming, .waiting, .someday, .all]

    var body: some View {
        List(selection: selection) {
            Section("Lists") { ForEach(builtIns, id: \.self) { routeRow($0) } }
            if let snapshot = workspace.snapshot {
                Section("Projects") {
                    ForEach(
                        snapshot.projects.values.map(\.value).sorted { $0.path.value < $1.path.value },
                        id: \.path
                    ) {
                        routeRow(.project($0.path), title: $0.title)
                    }
                }
                Section("Areas") {
                    ForEach(snapshot.areas.values.map(\.value).sorted { $0.path.value < $1.path.value }, id: \.path) {
                        routeRow(.area($0.path), title: $0.title)
                    }
                }
                let tags = Set(snapshot.tasks.values.flatMap(\.value.tags))
                    .union(snapshot.projects.values.flatMap(\.value.tags))
                    .union(snapshot.areas.values.flatMap(\.value.tags))
                    .sorted()
                if !tags.isEmpty {
                    Section("Tags") { ForEach(tags, id: \.self) { routeRow(.tag($0), title: $0) } }
                }
                Section("Priorities") {
                    ForEach(TaskPriority.allCases, id: \.self) {
                        routeRow(.priority($0), title: $0.rawValue.uppercased())
                    }
                }
                Section("Saved Filters") {
                    ForEach(workspace.savedFilters, id: \.name) { routeRow(.savedFilter($0.name)) }
                    Button("New Saved Filter", systemImage: "line.3.horizontal.decrease.circle") {
                        isCreatingFilter = true
                    }
                }
            }
            Section("Vault") {
                NavigationLink {
                    MobileSettingsView(workspace: workspace)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink {
                    MobileVaultStatusView(workspace: workspace)
                } label: {
                    Label("Vault Status", systemImage: "externaldrive.badge.icloud")
                }
                Button("Switch Vault", systemImage: "folder") { workspace.requestOpen() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("New Collection", systemImage: "plus") {
                    Button("New Project") {
                        newCollectionKind = .project
                        isCreatingCollection = true
                    }
                    Button("New Area") {
                        newCollectionKind = .area
                        isCreatingCollection = true
                    }
                }
            }
        }
        .sheet(isPresented: $isCreatingCollection) {
            MobileCollectionCreateView(workspace: workspace, kind: newCollectionKind)
        }
        .sheet(isPresented: $isCreatingFilter) {
            NavigationStack { MobileFilterEditorView(workspace: workspace) }
        }
    }

    @ViewBuilder private func routeRow(_ route: WorkspaceRoute, title: String? = nil) -> some View {
        if selection != nil {
            Text(title ?? route.title).tag(route)
        } else {
            NavigationLink(title ?? route.title, value: route)
        }
    }
}

private struct MobileVaultStatusView: View {
    let workspace: MobileWorkspace

    var body: some View {
        List {
            Section("Location") {
                LabeledContent("Vault", value: workspace.vaultName ?? "Unavailable")
            }
            Section("Availability") {
                switch workspace.snapshot?.scanCompleteness {
                case .complete: Label("Available files loaded", systemImage: "checkmark.circle")
                case let .partial(message): Label(message, systemImage: "exclamationmark.icloud")
                case nil: Label("Access required", systemImage: "folder.badge.questionmark")
                }
                if let refreshed = workspace.lastSuccessfulRefresh {
                    LabeledContent("Last refreshed") {
                        Text(refreshed, format: .dateTime.hour().minute().second())
                    }
                }
                Button("Retry") { Task { await workspace.refresh() } }
            }
            Section("Recovery") {
                NavigationLink {
                    MobileUnsavedChangesView(workspace: workspace)
                } label: {
                    Label("Unsaved Changes", systemImage: "square.and.pencil")
                }
            }
            if let conflicts = workspace.snapshot?.providerConflicts.values, !conflicts.isEmpty {
                Section("Conflicts") {
                    ForEach(conflicts.sorted { $0.path < $1.path }) { conflict in
                        NavigationLink {
                            MobileProviderConflictView(workspace: workspace, conflict: conflict)
                        } label: {
                            Label(conflict.path, systemImage: "exclamationmark.triangle")
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            if let diagnostics = workspace.snapshot?.diagnostics, !diagnostics.isEmpty {
                Section("Issues") {
                    ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, issue in
                        VStack(alignment: .leading) {
                            Text(issue.path?.value ?? "Vault").font(.caption.monospaced())
                            Text(issue.message)
                        }
                    }
                }
            }
        }
        .navigationTitle("Vault Status")
    }
}

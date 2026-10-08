import LocalTodoDomain
import LocalTodoWorkspace
import SwiftUI

struct MobileUnsavedChangesView: View {
    let workspace: MobileWorkspace
    @State private var taskDrafts = [TaskDraftCheckpoint]()
    @State private var captureDrafts = [CaptureDraftCheckpoint]()
    @State private var collectionDrafts = [CollectionDraftCheckpoint]()
    @State private var filterDrafts = [FilterDraftCheckpoint]()
    @State private var captureRoute: WorkspaceRoute?
    @State private var selectedFilterDraft: FilterDraftCheckpoint?

    var body: some View {
        List {
            if taskDrafts.isEmpty, captureDrafts.isEmpty, collectionDrafts.isEmpty, filterDrafts.isEmpty {
                ContentUnavailableView("No Unsaved Changes", systemImage: "checkmark.circle")
            }
            if !taskDrafts.isEmpty {
                Section("Task Drafts") {
                    ForEach(taskDrafts, id: \.path) { draft in
                        NavigationLink {
                            MobileTaskDetailView(workspace: workspace, path: draft.path)
                        } label: {
                            draftLabel(title: draft.title, detail: draft.path.value)
                        }
                        .swipeActions {
                            Button("Discard", role: .destructive) { discard(draft) }
                        }
                    }
                }
            }
            if !collectionDrafts.isEmpty {
                Section("Collection Drafts") {
                    ForEach(collectionDrafts) { draft in
                        NavigationLink {
                            MobileCollectionDetailView(workspace: workspace, path: draft.path)
                        } label: {
                            draftLabel(title: draft.title, detail: draft.path.value)
                        }
                        .swipeActions {
                            Button("Discard", role: .destructive) { discard(draft) }
                        }
                    }
                }
            }
            if !captureDrafts.isEmpty {
                Section("New Task Drafts") {
                    ForEach(captureDrafts) { draft in
                        Button {
                            captureRoute = route(for: draft.routeKey)
                        } label: {
                            draftLabel(
                                title: draft.title.isEmpty ? "Untitled Task" : draft.title,
                                detail: "New task in \(draft.routeKey)"
                            )
                        }
                        .swipeActions {
                            Button("Discard", role: .destructive) { discard(draft) }
                        }
                    }
                }
            }
            if !filterDrafts.isEmpty {
                Section("Saved Filter Drafts") {
                    ForEach(filterDrafts) { draft in
                        Button {
                            selectedFilterDraft = draft
                        } label: {
                            draftLabel(
                                title: draft.name.isEmpty ? "Untitled Filter" : draft.name,
                                detail: draft.originalName.map { "Editing \($0)" } ?? "New saved filter"
                            )
                        }
                        .swipeActions {
                            Button("Discard", role: .destructive) { discard(draft) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Unsaved Changes")
        .task { await reload() }
        .sheet(item: $captureRoute) { route in
            MobileCaptureView(workspace: workspace, route: route)
                .onDisappear { Task { await reload() } }
        }
        .sheet(item: $selectedFilterDraft) { draft in
            let existing = draft.originalName.flatMap { name in
                workspace.savedFilters.first { $0.name == name }
            }
            NavigationStack {
                MobileFilterEditorView(
                    workspace: workspace,
                    existing: existing,
                    checkpointOriginalName: draft.originalName
                )
            }
            .onDisappear { Task { await reload() } }
        }
    }

    private func draftLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).foregroundStyle(.primary)
            Text(detail).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }

    private func reload() async {
        guard let identifier = workspace.vaultIdentifier else { return }
        taskDrafts = await (try? workspace.checkpoints.checkpoints())?.filter {
            $0.vaultIdentifier == identifier
        } ?? []
        captureDrafts = await (try? workspace.captureCheckpoints.checkpoints())?.filter {
            $0.vaultIdentifier == identifier
        } ?? []
        collectionDrafts = await (try? workspace.collectionCheckpoints.checkpoints())?.filter {
            $0.vaultIdentifier == identifier
        } ?? []
        filterDrafts = await (try? workspace.filterCheckpoints.checkpoints())?.filter {
            $0.vaultIdentifier == identifier
        } ?? []
    }

    private func discard(_ draft: TaskDraftCheckpoint) {
        Task {
            try? await workspace.checkpoints.remove(
                vaultIdentifier: draft.vaultIdentifier,
                path: draft.path,
                through: draft.generation
            )
            await reload()
        }
    }

    private func discard(_ draft: CaptureDraftCheckpoint) {
        Task {
            try? await workspace.captureCheckpoints.remove(
                vaultIdentifier: draft.vaultIdentifier,
                routeKey: draft.routeKey,
                through: draft.generation
            )
            await reload()
        }
    }

    private func discard(_ draft: CollectionDraftCheckpoint) {
        Task {
            try? await workspace.collectionCheckpoints.remove(
                vaultIdentifier: draft.vaultIdentifier,
                path: draft.path,
                through: draft.generation
            )
            await reload()
        }
    }

    private func discard(_ draft: FilterDraftCheckpoint) {
        Task {
            try? await workspace.filterCheckpoints.remove(
                vaultIdentifier: draft.vaultIdentifier,
                editorKey: draft.editorKey,
                through: draft.generation
            )
            await reload()
        }
    }

    private func route(for key: String) -> WorkspaceRoute {
        switch key {
        case "today": .today
        case "inbox": .inbox
        case "next": .next
        case "upcoming": .upcoming
        case "waiting": .waiting
        case "someday": .someday
        case "completed": .completed
        case "search": .search
        default: dynamicRoute(for: key) ?? .all
        }
    }

    private func dynamicRoute(for key: String) -> WorkspaceRoute? {
        if key.hasPrefix("project:"), let path = try? VaultPath(String(key.dropFirst(8))) {
            return .project(path)
        }
        if key.hasPrefix("area:"), let path = try? VaultPath(String(key.dropFirst(5))) {
            return .area(path)
        }
        if key.hasPrefix("tag:") {
            return .tag(String(key.dropFirst(4)))
        }
        if key.hasPrefix("filter:") {
            return .savedFilter(String(key.dropFirst(7)))
        }
        if key == "priority:none" {
            return .priority(nil)
        }
        if key.hasPrefix("priority:") {
            return .priority(TaskPriority(rawValue: String(key.dropFirst(9))))
        }
        return nil
    }
}

extension WorkspaceRoute: @retroactive Identifiable {
    public var id: String {
        listPreferencesKey
    }
}

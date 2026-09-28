import LocalTodoDomain
import LocalTodoWorkspace
import SwiftUI

struct MobileCollectionCreateView: View {
    @Environment(\.dismiss) private var dismiss
    let workspace: MobileWorkspace
    let kind: WorkspaceCollectionKind
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form { TextField(kind == .project ? "Project title" : "Area title", text: $title) }
                .navigationTitle(kind == .project ? "New Project" : "New Area")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task {
                                if await workspace.createCollection(kind: kind, title: title) != nil {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}

struct MobileCollectionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let workspace: MobileWorkspace
    let path: VaultPath
    @State private var title = ""
    @State private var bodyText = ""
    @State private var projectStatus: ProjectStatus = .active
    @State private var areaStatus: AreaStatus = .active
    @State private var areaPath = ""
    @State private var tagsText = ""
    @State private var confirmsDeletion = false
    @State private var checkpointGeneration: UInt64 = 0
    @State private var recoveredDraft = false
    @State private var pendingCheckpoint: CollectionDraftCheckpoint?

    var body: some View {
        Form {
            if recoveredDraft {
                Section { Label("Draft recovered on this device", systemImage: "arrow.counterclockwise") }
            } else if pendingCheckpoint != nil {
                Section("Recovered Draft") {
                    Text("The vault file changed after this collection draft was saved.")
                    Button("Apply Recovered Values") { applyPendingCheckpoint() }
                    Button("Discard Recovered Draft", role: .destructive) {
                        Task { await discardCheckpoint() }
                    }
                }
            }
            Section("Collection") {
                TextField("Title", text: $title)
                TextEditor(text: $bodyText).frame(minHeight: 140)
            }
            if project != nil {
                Section("Project") {
                    Picker("Status", selection: $projectStatus) {
                        ForEach(ProjectStatus.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    Picker("Area", selection: $areaPath) {
                        Text("None").tag("")
                        ForEach(areas, id: \.path) { Text($0.title).tag($0.path.value) }
                    }
                }
            } else {
                Section("Area") {
                    Picker("Status", selection: $areaStatus) {
                        ForEach(AreaStatus.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                }
            }
            Section("Organization") {
                TextField("Tags, one per line", text: $tagsText, axis: .vertical)
            }
            Section {
                Button("Delete Collection", role: .destructive) { confirmsDeletion = true }
            } footer: {
                Text("Deletion is blocked while tasks, projects, or saved filters still reference this collection.")
            }
        }
        .navigationTitle(project != nil ? "Project" : "Area")
        .task(id: recordRevision) { await load() }
        .task(id: draftFingerprint) {
            try? await Task.sleep(for: .milliseconds(600))
            await checkpointIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await checkpointIfNeeded() }
            }
        }
        .onDisappear { Task { await checkpointIfNeeded() } }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }.disabled(title.isEmpty)
            }
        }
        .confirmationDialog("Delete this collection?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if await workspace.deleteCollection(at: path) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var project: Project? {
        workspace.snapshot?.projects[path]?.value
    }

    private var area: Area? {
        workspace.snapshot?.areas[path]?.value
    }

    private var recordRevision: String? {
        workspace.snapshot?.projects[path]?.revision.value ?? workspace.snapshot?.areas[path]?.revision.value
    }

    private var areas: [Area] {
        workspace.snapshot?.areas.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    private func load() async {
        if let project {
            title = project.title
            bodyText = project.body
            projectStatus = project.status
            areaPath = project.area?.value ?? ""
            tagsText = project.tags.joined(separator: "\n")
        } else if let area {
            title = area.title
            bodyText = area.body
            areaStatus = area.status
            tagsText = area.tags.joined(separator: "\n")
        }
        await loadCheckpoint()
    }

    private func save() async {
        let tags = tagsText.split(whereSeparator: \.isNewline).map(String.init)
        if let project {
            guard await workspace.updateProject(at: path, patch: projectPatch(project, tags: tags)) else { return }
        } else if let area {
            guard await workspace.updateArea(at: path, patch: areaPatch(area, tags: tags)) else { return }
        }
        await discardCheckpoint()
    }

    private func projectPatch(_ project: Project, tags: [String]) -> ProjectPatch {
        var patch = ProjectPatch()
        if title != project.title {
            patch.title = .set(title)
        }
        if bodyText != project.body {
            patch.body = .set(bodyText)
        }
        if projectStatus != project.status {
            patch.status = .set(projectStatus)
        }
        let nextArea = areaPath.isEmpty ? nil : try? VaultPath(areaPath)
        if nextArea != project.area {
            patch.area = .set(nextArea)
        }
        if tags != project.tags {
            patch.tags = .set(tags)
        }
        return patch
    }

    private func areaPatch(_ area: Area, tags: [String]) -> AreaPatch {
        var patch = AreaPatch()
        if title != area.title {
            patch.title = .set(title)
        }
        if bodyText != area.body {
            patch.body = .set(bodyText)
        }
        if areaStatus != area.status {
            patch.status = .set(areaStatus)
        }
        if tags != area.tags {
            patch.tags = .set(tags)
        }
        return patch
    }
}

private extension MobileCollectionDetailView {
    var draftFingerprint: String {
        [title, bodyText, projectStatus.rawValue, areaStatus.rawValue, areaPath, tagsText].joined(separator: "\u{1f}")
    }

    var hasChanges: Bool {
        if let project {
            return title != project.title || bodyText != project.body || projectStatus != project.status
                || (areaPath.isEmpty ? nil : try? VaultPath(areaPath)) != project.area
                || tagsText.split(whereSeparator: \.isNewline).map(String.init) != project.tags
        }
        guard let area else { return false }
        return title != area.title || bodyText != area.body || areaStatus != area.status
            || tagsText.split(whereSeparator: \.isNewline).map(String.init) != area.tags
    }

    func checkpointIfNeeded() async {
        guard hasChanges, let identifier = workspace.vaultIdentifier, let revision = recordRevision else { return }
        checkpointGeneration += 1
        let checkpoint = CollectionDraftCheckpoint(
            vaultIdentifier: identifier,
            path: path,
            baseRevision: revision,
            generation: checkpointGeneration,
            title: title,
            body: bodyText,
            projectStatus: project == nil ? nil : projectStatus,
            areaStatus: area == nil ? nil : areaStatus,
            area: areaPath.isEmpty ? nil : try? VaultPath(areaPath),
            tags: tagsText.split(whereSeparator: \.isNewline).map(String.init)
        )
        do {
            try await workspace.collectionCheckpoints.save(checkpoint)
        } catch {
            workspace.errorMessage = "The collection recovery draft could not be saved. \(error.localizedDescription)"
        }
    }

    func loadCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier,
              let checkpoint = try? await workspace.collectionCheckpoints.checkpoints().first(where: {
                  $0.vaultIdentifier == identifier && $0.path == path
              }) else { return }
        checkpointGeneration = checkpoint.generation
        if checkpoint.baseRevision == recordRevision {
            apply(checkpoint)
            recoveredDraft = true
        } else {
            pendingCheckpoint = checkpoint
        }
    }

    func applyPendingCheckpoint() {
        guard let pendingCheckpoint else { return }
        apply(pendingCheckpoint)
        recoveredDraft = true
        self.pendingCheckpoint = nil
    }

    func apply(_ checkpoint: CollectionDraftCheckpoint) {
        title = checkpoint.title
        bodyText = checkpoint.body
        projectStatus = checkpoint.projectStatus ?? projectStatus
        areaStatus = checkpoint.areaStatus ?? areaStatus
        areaPath = checkpoint.area?.value ?? ""
        tagsText = checkpoint.tags.joined(separator: "\n")
    }

    func discardCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier else { return }
        try? await workspace.collectionCheckpoints.remove(
            vaultIdentifier: identifier,
            path: path,
            through: checkpointGeneration
        )
        recoveredDraft = false
        pendingCheckpoint = nil
    }
}

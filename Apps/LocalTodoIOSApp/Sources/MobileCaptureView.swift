import LocalTodoDomain
import LocalTodoWorkspace
import SwiftUI

struct MobileCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var titleFocused: Bool
    let workspace: MobileWorkspace
    let route: WorkspaceRoute
    @State private var title = ""
    @State private var notes = ""
    @State private var status: TaskStatus?
    @State private var priority: TaskPriority?
    @State private var hasScheduled = false
    @State private var scheduled = Date()
    @State private var projectPath = ""
    @State private var areaPath = ""
    @State private var tags = ""
    @State private var isSubmitting = false
    @State private var checkpointGeneration: UInt64 = 0
    @State private var recoveredDraft = false
    @State private var isFinished = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title, axis: .vertical).focused($titleFocused)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                Section("Planning") {
                    Picker("Status", selection: $status) {
                        Text("Context Default").tag(TaskStatus?.none)
                        ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                    }
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(TaskPriority?.none)
                        ForEach(TaskPriority.allCases, id: \.self) {
                            Text($0.rawValue.uppercased()).tag(Optional($0))
                        }
                    }
                    Toggle("Scheduled", isOn: $hasScheduled)
                    if hasScheduled {
                        DatePicker("Date", selection: $scheduled, displayedComponents: .date)
                    }
                }
                Section("Organization") {
                    Picker("Project", selection: $projectPath) {
                        Text("Context Default").tag("")
                        ForEach(projects, id: \.path) { Text($0.title).tag($0.path.value) }
                    }
                    Picker("Area", selection: $areaPath) {
                        Text("Context Default").tag("")
                        ForEach(areas, id: \.path) { Text($0.title).tag($0.path.value) }
                    }
                    TextField("Tags, one per line", text: $tags, axis: .vertical)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu("Close") {
                        Button("Keep Draft") { dismiss() }
                        Button("Discard Draft", role: .destructive) {
                            Task {
                                isFinished = true
                                await discardCheckpoint()
                                dismiss()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            isSubmitting = true
                            if await workspace.capture(title: title, route: route, patch: capturePatch) {
                                isFinished = true
                                await discardCheckpoint()
                                dismiss()
                            }
                            isSubmitting = false
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .safeAreaInset(edge: .top) {
                if recoveredDraft {
                    Label("Draft recovered on this device", systemImage: "arrow.counterclockwise")
                        .font(.caption).padding(8).frame(maxWidth: .infinity).background(.bar)
                }
            }
            .task {
                await loadCheckpoint()
                titleFocused = true
            }
            .task(id: draftFingerprint) {
                try? await Task.sleep(for: .milliseconds(500))
                await checkpointIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    Task { await checkpointIfNeeded() }
                }
            }
            .onDisappear { Task { await checkpointIfNeeded() } }
        }
    }
}

private extension MobileCaptureView {
    private var projects: [Project] {
        workspace.snapshot?.projects.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    private var areas: [Area] {
        workspace.snapshot?.areas.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    private var capturePatch: TaskPatch {
        var patch = TaskPatch()
        if !notes.isEmpty {
            patch.body = .set(notes)
        }
        if let status {
            patch.status = .set(status)
        }
        if let priority {
            patch.priority = .set(priority)
        }
        if hasScheduled, let date = try? CalendarDate(date: scheduled, calendar: vaultCalendar) {
            patch.scheduled = .set(date)
        }
        if !projectPath.isEmpty {
            patch.project = .set(try? VaultPath(projectPath))
        }
        if !areaPath.isEmpty {
            patch.area = .set(try? VaultPath(areaPath))
        }
        let tagValues = tags.split(whereSeparator: \.isNewline).map(String.init)
        if !tagValues.isEmpty {
            patch.tags = .set(tagValues)
        }
        return patch
    }

    private var vaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let identifier = workspace.snapshot?.configuration.timezone {
            if let timezone = TimeZone(identifier: identifier) {
                calendar.timeZone = timezone
            }
        }
        return calendar
    }

    private var draftFingerprint: String {
        [
            title, notes, status?.rawValue ?? "", priority?.rawValue ?? "", String(hasScheduled),
            scheduled.description, projectPath, areaPath, tags,
        ].joined(separator: "\u{1f}")
    }

    private var hasDraftContent: Bool {
        !title.isEmpty || !notes.isEmpty || status != nil || priority != nil || hasScheduled
            || !projectPath.isEmpty || !areaPath.isEmpty || !tags.isEmpty
    }

    private func checkpointIfNeeded() async {
        guard !isFinished, hasDraftContent, let identifier = workspace.vaultIdentifier else { return }
        checkpointGeneration += 1
        let checkpoint = CaptureDraftCheckpoint(
            vaultIdentifier: identifier,
            routeKey: route.listPreferencesKey,
            generation: checkpointGeneration,
            title: title,
            notes: notes,
            status: status,
            priority: priority,
            scheduled: hasScheduled ? try? CalendarDate(date: scheduled, calendar: vaultCalendar) : nil,
            project: projectPath.isEmpty ? nil : try? VaultPath(projectPath),
            area: areaPath.isEmpty ? nil : try? VaultPath(areaPath),
            tags: tags.split(whereSeparator: \.isNewline).map(String.init)
        )
        do {
            try await workspace.captureCheckpoints.save(checkpoint)
        } catch {
            workspace.errorMessage = "The capture recovery draft could not be saved. \(error.localizedDescription)"
        }
    }

    private func loadCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier,
              let checkpoint = try? await workspace.captureCheckpoints.checkpoints().first(where: {
                  $0.vaultIdentifier == identifier && $0.routeKey == route.listPreferencesKey
              }) else { return }
        checkpointGeneration = checkpoint.generation
        title = checkpoint.title
        notes = checkpoint.notes
        status = checkpoint.status
        priority = checkpoint.priority
        if let value = checkpoint.scheduled, let date = try? value.date(in: vaultCalendar) {
            scheduled = date
            hasScheduled = true
        }
        projectPath = checkpoint.project?.value ?? ""
        areaPath = checkpoint.area?.value ?? ""
        tags = checkpoint.tags.joined(separator: "\n")
        recoveredDraft = true
    }

    private func discardCheckpoint() async {
        guard let identifier = workspace.vaultIdentifier else { return }
        try? await workspace.captureCheckpoints.remove(
            vaultIdentifier: identifier,
            routeKey: route.listPreferencesKey,
            through: checkpointGeneration
        )
        recoveredDraft = false
    }
}

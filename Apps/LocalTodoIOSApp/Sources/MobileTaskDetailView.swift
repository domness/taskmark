import LocalTodoDomain
import LocalTodoWorkspace
import SwiftUI
import UIKit

struct MobileTaskDetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    let workspace: MobileWorkspace
    let path: VaultPath
    @State var title = ""
    @State var bodyText = ""
    @State var status: TaskStatus = .inbox
    @State var priority: TaskPriority?
    @State var scheduledDate = Date()
    @State var hasScheduledDate = false
    @State var deadlineDate = Date()
    @State var hasDeadlineDate = false
    @State var projectPath = ""
    @State var areaPath = ""
    @State var tagsText = ""
    @State var recurrence = RecurrenceEditorValue(nil)
    @State var resetChecklistOnRepeat = false
    @State var checkpointGeneration: UInt64 = 0
    @State var recoveredDraft = false
    @State var pendingConflictedCheckpoint: TaskDraftCheckpoint?
    @State private var isEditingSource = false
    @State var exactMarkdown = ""

    var task: TodoTask? {
        workspace.snapshot?.tasks[path]?.value
    }

    var body: some View {
        Form {
            if workspace.isSaving {
                Section { Label("Saving…", systemImage: "arrow.triangle.2.circlepath") }
            } else if hasChanges {
                Section { Label("Unsaved changes", systemImage: "pencil.and.list.clipboard") }
            } else {
                Section { Label("Saved to vault", systemImage: "checkmark.circle") }
            }
            if recoveredDraft {
                Section {
                    Label(
                        "Draft recovered on this device — not yet saved to the vault",
                        systemImage: "arrow.counterclockwise"
                    )
                }
            } else if pendingConflictedCheckpoint != nil {
                Section("Recovered Draft") {
                    Text("The vault file changed after this draft was checkpointed. Review before applying it.")
                    Button("Apply Recovered Values") { applyPendingCheckpoint() }
                    Button("Discard Recovered Draft", role: .destructive) {
                        Task { await discardCheckpoint() }
                    }
                }
            }
            Section("Task") {
                if isEditingSource {
                    TextField("Title", text: $title, axis: .vertical)
                    TextEditor(text: $bodyText).frame(minHeight: 160)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Button {
                            Task { await workspace.complete(path) }
                        } label: {
                            Image(systemName: task?.status.isComplete == true ? "checkmark.circle.fill" : "circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(task?.status.isComplete == true ? "Reopen task" : "Complete task")
                        Text(.init(title)).font(.title2.weight(.semibold))
                    }
                    if !bodyText.isEmpty {
                        Text(.init(bodyText)).textSelection(.enabled)
                    }
                    Button("Edit Markdown", systemImage: "pencil") { isEditingSource = true }
                }
            }
            Section("Planning") {
                Picker("Status", selection: $status) {
                    ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Priority", selection: $priority) {
                    Text("None").tag(TaskPriority?.none)
                    ForEach(TaskPriority.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag(Optional($0)) }
                }
                Toggle("Scheduled", isOn: $hasScheduledDate)
                if hasScheduledDate {
                    DatePicker("Scheduled Date", selection: $scheduledDate, displayedComponents: .date)
                }
                Toggle("Deadline", isOn: $hasDeadlineDate)
                if hasDeadlineDate {
                    DatePicker("Deadline Date", selection: $deadlineDate, displayedComponents: .date)
                }
            }
            Section("Repeat") {
                Picker("Repeat", selection: $recurrence.mode) {
                    ForEach(RecurrenceEditorValue.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if recurrence.mode != .none {
                    Stepper("Every \(recurrence.interval)", value: $recurrence.interval, in: 1 ... 999)
                    if recurrence.mode == .fixed {
                        Picker("Frequency", selection: $recurrence.frequency) {
                            ForEach(FixedRecurrenceRule.Frequency.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        if recurrence.frequency == .weekly {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                Toggle(day.title, isOn: weekdayBinding(day))
                            }
                        }
                    } else {
                        Picker("Unit", selection: $recurrence.unit) {
                            Text("Days").tag(RecurrenceInterval.Unit.day)
                            Text("Weeks").tag(RecurrenceInterval.Unit.week)
                            Text("Months").tag(RecurrenceInterval.Unit.month)
                            Text("Years").tag(RecurrenceInterval.Unit.year)
                        }
                    }
                    Toggle("Reset checklist on repeat", isOn: $resetChecklistOnRepeat)
                }
            }
            Section("Organization") {
                Picker("Project", selection: $projectPath) {
                    Text("None").tag("")
                    ForEach(projects, id: \.path) { Text($0.title).tag($0.path.value) }
                }
                Picker("Area", selection: $areaPath) {
                    Text("None").tag("")
                    ForEach(areas, id: \.path) { Text($0.title).tag($0.path.value) }
                }
                TextField("Tags, one per line", text: $tagsText, axis: .vertical)
            }
            let checklist = MarkdownChecklist(bodyText)
            if !checklist.items.isEmpty {
                Section("Checklist") {
                    ForEach(checklist.items) { item in
                        Toggle(item.title, isOn: Binding(
                            get: { item.isChecked },
                            set: { checked in
                                bodyText = (try? checklist.settingChecked(checked, item: item)) ?? bodyText
                            }
                        ))
                    }
                }
            }
            if let task {
                Section("File") {
                    Text(task.path.value).font(.caption.monospaced())
                    Button("Copy Title", systemImage: "doc.on.doc") { UIPasteboard.general.string = task.title }
                    Button("Copy Markdown", systemImage: "doc.on.doc") { UIPasteboard.general.string = exactMarkdown }
                    Button("Copy Relative Path", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = task.path.value
                    }
                    ShareLink(item: exactMarkdown, subject: Text(task.title)) {
                        Label("Share Markdown Copy", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle("Task")
        .task(id: task) { await loadTask() }
        .task(id: draftFingerprint) {
            do {
                try await Task.sleep(for: .milliseconds(600))
                await checkpointIfNeeded()
            } catch {}
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await checkpointIfNeeded() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditingSource || hasChanges ? "Save" : "Edit") {
                    if isEditingSource || hasChanges {
                        Task {
                            await save()
                            isEditingSource = false
                        }
                    } else {
                        isEditingSource = true
                    }
                }
                .disabled(task == nil || title.isEmpty)
            }
        }
    }

    var projects: [Project] {
        workspace.snapshot?.projects.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    var areas: [Area] {
        workspace.snapshot?.areas.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    var vaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let identifier = workspace.snapshot?.configuration.timezone {
            if let timezone = TimeZone(identifier: identifier) {
                calendar.timeZone = timezone
            }
        }
        return calendar
    }
}

private extension MobileTaskDetailView {
    func weekdayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { recurrence.weekdays.contains(day) },
            set: { enabled in
                recurrence.weekdays = Weekday.allCases.filter {
                    $0 == day ? enabled : recurrence.weekdays.contains($0)
                }
            }
        )
    }
}

private extension Weekday {
    var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
}

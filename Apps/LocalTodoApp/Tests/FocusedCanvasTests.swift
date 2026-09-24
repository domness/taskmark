import AppKit
@testable import LocalTodoApp
import LocalTodoDomain
import SwiftUI
import Testing

@MainActor
struct FocusedCanvasTests {
    @Test func selectionPreservesExplicitInspectorVisibility() async throws {
        try await withWorkspace { model, _ in
            #expect(!model.isInspectorPresented)
            await model.createTask(title: "Read the proposal", vaultSession: model.vaultSession)
            let path = try #require(model.selectedTaskPath)
            model.isInspectorPresented = false
            model.selectTask(path)
            #expect(!model.isInspectorPresented)
            model.beginInlineTitleEditing(at: path)
            #expect(!model.isInspectorPresented)
            model.editTask(at: path)
            #expect(model.isInspectorPresented)
            model.selectTask(nil)
            #expect(model.isInspectorPresented)
        }
    }

    @Test func quietDefaultsKeepOrganizationAvailable() {
        let today = TaskListDisplayOptions.defaults(for: .today)
        #expect(today.grouping == .project)
        #expect(today.showsProject)
        #expect(!today.showsTags)
        #expect(!today.showsArea)
    }

    @Test func todayHidesOnlyItsRedundantScheduledDate() throws {
        let today = try CalendarDate("2026-09-21")
        let past = try CalendarDate("2026-09-20")
        #expect(!TaskListDisplayOptions.showsScheduledDate(today, route: .today, today: today))
        #expect(TaskListDisplayOptions.showsScheduledDate(past, route: .today, today: today))
        #expect(TaskListDisplayOptions.showsScheduledDate(today, route: .inbox, today: today))
        #expect(TaskListDisplayOptions.showsScheduledDate(today, route: .today, today: nil))
    }

    /// Full WindowServer capture of production views with an isolated example vault.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TASKMARK_CANVAS_CAPTURES"] != nil))
    func captureNativeCanvas() async throws {
        try await withWorkspace { model, _ in
            let project = try await prepareCapture(model)
            let controller = NSHostingController(rootView: WorkspaceView(model: model)
                .modifier(AppAppearanceModifier(model: model)))
            let window = NSWindow(contentViewController: controller)
            window.isReleasedWhenClosed = false
            window.title = "Taskmark"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 1120, height: 720))
            window.center()
            window.makeKeyAndOrderFront(nil)
            defer { window.close() }
            for (name, inspector, appearance) in [
                ("focused-canvas", false, AppAppearance.light),
                ("notes-inspector", true, AppAppearance.light),
                ("focused-canvas-dark", false, AppAppearance.dark),
                ("project-canvas", false, AppAppearance.light),
            ] {
                if name == "project-canvas" {
                    model.route = .project(project)
                }
                if inspector {
                    let task = try #require(model.visibleTasks.first { $0.title == "Plan a quieter week" })
                    model.selectTask(task.path)
                }
                model.isInspectorPresented = inspector
                model.preferences.appearance = appearance
                window.appearance = NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
                try await Task.sleep(for: .seconds(1))
                print("TASKMARK_CAPTURE \(window.windowNumber) \(name)")
                try await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func prepareCapture(_ model: WorkspaceModel) async throws -> VaultPath {
        let project = try VaultPath("Projects/Autumn launch.md")
        await model.createCollection(kind: .project, path: project.value, title: "Autumn launch")
        model.route = .project(project)
        model.prepareProjectDraft()
        model.selectedProjectDraft?.notes = "A thoughtful release, with room to focus on the details."
        for title in ["Review the launch checklist", "Send the design proposal", "Plan a quieter week"] {
            await model.createTask(title: title, vaultSession: model.vaultSession, captureRoute: .today)
            let draft = try #require(model.selectedTaskDraft)
            draft.project = project.value
            if title == "Send the design proposal" {
                draft.scheduled = "2026-09-20"
                draft.priority = .p2
            }
        }
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "Make room for the work that matters.\n\n"
            + "Review priorities and share the next steps with the team."
        #expect(await model.flushTaskChanges())
        model.route = .today
        return project
    }
}

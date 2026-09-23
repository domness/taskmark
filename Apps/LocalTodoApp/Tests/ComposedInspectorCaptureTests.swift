import AppKit
@testable import LocalTodoApp
import LocalTodoDomain
import SwiftUI
import Testing

/// Content-only layout evidence; excludes window chrome, active-window styling and native popovers.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["TASKMARK_INSPECTOR_CAPTURES"] != nil))
func captureComposedInspector() async throws {
    let directory = try #require(ProcessInfo.processInfo.environment["TASKMARK_INSPECTOR_CAPTURES"])
    try await withWorkspace { model, _ in
        let draft = try await prepareInspectorCapture(model)
        let controller = NSHostingController(rootView: TaskInspectorView(model: model, draft: draft)
            .themeSurface("--inspector-background")
            .modifier(AppAppearanceModifier(model: model)))
        let window = NSWindow(contentViewController: controller)
        window.isReleasedWhenClosed = false
        window.title = "Taskmark"
        window.setContentSize(NSSize(width: 340, height: 740))
        window.center()
        defer { window.close() }
        try await presentForNativeInput(window)
        for appearance in [AppAppearance.light, .dark] {
            model.preferences.appearance = appearance
            window.appearance = NSAppearance(named: appearance == .light ? .aqua : .darkAqua)
            try await Task.sleep(for: .seconds(1))
            try captureContent(window, directory: directory, name: "composed-inspector-\(appearance.rawValue)")
        }
        draft.tags = ["Design", "Review", "A long tag that needs to fit in the inspector"]
        draft.project = "Projects/Missing project.md"
        draft.recurrence = try .afterCompletion(RecurrenceInterval(value: 3, unit: .day))
        window.setContentSize(NSSize(width: 280, height: 820))
        try await Task.sleep(for: .seconds(1))
        try captureContent(window, directory: directory, name: "composed-inspector-narrow")
    }
}

@MainActor
private func captureContent(_ window: NSWindow, directory: String, name: String) throws {
    let view = try #require(window.contentView)
    view.layoutSubtreeIfNeeded()
    let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name)-content.png"))
}

@MainActor
private func prepareInspectorCapture(_ model: WorkspaceModel) async throws -> TaskDraft {
    let project = "Projects/Autumn launch.md"
    await model.createCollection(kind: .project, path: project, title: "Autumn launch")
    await model.createTask(title: "Review the launch proposal and share feedback", vaultSession: model.vaultSession)
    let draft = try #require(model.selectedTaskDraft)
    draft.notes = "Check the updated designs before the team review.\n\n"
        + "Focus on the onboarding flow and keyboard navigation."
    draft.status = .next
    draft.priority = .p2
    draft.project = project
    draft.tags = ["Design"]
    draft.scheduled = try CalendarDate(date: model.clock(), calendar: model.vaultCalendar).description
    #expect(await model.flushTaskChanges())
    return draft
}

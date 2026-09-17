import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func duplicatePreservesPendingNotesAndUnknownMetadata() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Source", vaultSession: model.vaultSession)
        let path = try #require(model.selectedTaskPath)
        let url = root.appendingPathComponent(path.value)
        let original = try String(contentsOf: url, encoding: .utf8)
        try original.replacingOccurrences(of: "type: task", with: "type: task\ncustom: keep-me")
            .write(to: url, atomically: true, encoding: .utf8)
        await model.refresh()
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "- [x] Pending notes\n"
        await model.duplicateTask(at: path)
        let copyPath = try #require(model.selectedTaskPath)
        #expect(copyPath != path)
        #expect(model.snapshot?.tasks[copyPath]?.value.body == "- [x] Pending notes\n")
        #expect(try String(contentsOf: root.appendingPathComponent(copyPath.value), encoding: .utf8)
            .contains("custom: keep-me"))
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func deleteUndoRestoresExactMarkdownAndRedoDeletes() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Reversible", vaultSession: model.vaultSession)
        let path = try #require(model.selectedTaskPath)
        let url = root.appendingPathComponent(path.value)
        let original = try String(contentsOf: url, encoding: .utf8)
        try original.replacingOccurrences(of: "type: task", with: "type: task\ncustom: [one, two]")
            .write(to: url, atomically: true, encoding: .utf8)
        await model.refresh()
        let content = try Data(contentsOf: url)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        await model.deleteTask(at: path)
        undo.endUndoGrouping()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(try Data(contentsOf: url) == content)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func staleDeleteDoesNotRemoveExternalChanges() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Keep", vaultSession: model.vaultSession)
        let path = try #require(model.selectedTaskPath)
        let url = root.appendingPathComponent(path.value)
        var content = try Data(contentsOf: url)
        content.append(Data("External notes".utf8))
        try content.write(to: url)
        await model.deleteTask(at: path)
        #expect(try Data(contentsOf: url) == content)
        #expect(model.errorMessage != nil)
    }
}

@MainActor
@Test func duplicateHistorySurvivesAnInAppRevisionChange() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Source", vaultSession: model.vaultSession)
        let source = try #require(model.selectedTaskPath)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        await model.duplicateTask(at: source)
        undo.endUndoGrouping()
        let copy = try #require(model.selectedTaskPath)
        let draft = try #require(model.selectedTaskDraft)
        // An edit followed by its undo may restore the content with a different updated_at revision.
        draft.notes = "Temporary"
        await model.updateTask(draft)
        draft.notes = ""
        await model.updateTask(draft)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(model.snapshot?.tasks[copy] == nil)
        #expect(model.snapshot?.tasks[source] != nil)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(model.snapshot?.tasks[copy]?.value.title == "Source (Copy)")
        #expect(model.errorMessage == nil)
    }
}

@Test func sidebarOrderKeepsNewPathsAndIgnoresMissingPaths() throws {
    let paths = try ["Projects/a.md", "Projects/b.md", "Projects/c.md"].map(VaultPath.init)
    let sorted = SidebarOrder.sorted(paths, order: ["Projects/gone.md", paths[1].value])
    #expect(sorted == [paths[1], paths[0], paths[2]])
}

@Test func stylesheetSupportsNativeTokensAndRejectsUnsupportedCSS() throws {
    let appearance = try VaultAppearance.parse("""
    /* native tokens */
    :root { --priority-1: #cc2233; --row-spacing: 6px; }
    :root[data-appearance=dark] { --priority-1: #ff8899; }
    """)
    #expect(appearance.light["--priority-1"] == "#cc2233")
    #expect(appearance.dark["--priority-1"] == "#ff8899")
    #expect(appearance.number("--row-spacing", scheme: .dark, fallback: 3) == 6)
    #expect(throws: AppearanceError.self) { try VaultAppearance.parse("body { display: none; }") }
    #expect(throws: AppearanceError.self) { try VaultAppearance.parse(":root { --row-spacing: -2px; }") }
    #expect(throws: AppearanceError.self) { try VaultAppearance.parse(":root { --accent: red; }") }
}

@MainActor
@Test func stylesheetReloadsAndFallsBackWithoutChangingUserContent() async throws {
    try await withWorkspace { model, root in
        let directory = root.appendingPathComponent(".config")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("style.css")
        try ":root { --row-spacing: 8px; }".write(to: url, atomically: true, encoding: .utf8)
        await model.refreshAppearance()
        #expect(model.vaultAppearance.light["--row-spacing"] == "8px")
        let invalid = "button { display: none; }"
        try invalid.write(to: url, atomically: true, encoding: .utf8)
        await model.refreshAppearance()
        #expect(model.vaultAppearance == VaultAppearance())
        #expect(model.stylesheetDiagnostic != nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == invalid)
        try FileManager.default.removeItem(at: url)
        await model.refreshAppearance()
        #expect(model.stylesheetDiagnostic == nil)
    }
}

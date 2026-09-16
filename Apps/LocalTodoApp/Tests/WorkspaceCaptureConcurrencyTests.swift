import Foundation
@testable import LocalTodoApp
import LocalTodoMarkdown
import Testing

@MainActor
@Test(arguments: [false, true])
func completedCapturePreservesNewerInput(reopenWithSameTitle: Bool) async throws {
    try await withWorkspace { model, root in
        let fileSystem = PausingCreationFileSystem()
        defer { fileSystem.release() }
        model.store = VaultStore(root: root, fileSystem: fileSystem)
        model.beginQuickCapture()
        model.quickCaptureTitle = "First"
        let saving = Task { await model.createTask(title: "First", vaultSession: model.vaultSession) }
        for _ in 0 ..< 100 where !fileSystem.hasPaused {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(fileSystem.hasPaused)
        if reopenWithSameTitle {
            model.cancelQuickCapture()
            model.beginQuickCapture()
            model.quickCaptureTitle = "First"
        } else {
            model.quickCaptureTitle = "Next task"
        }
        let expected = model.quickCaptureTitle
        fileSystem.release()
        await saving.value
        #expect(model.quickCaptureTitle == expected)
        #expect(model.isQuickCapturePresented)
        let saved = try await VaultStore(root: root).snapshot()
        #expect(saved.tasks.values.map(\.value.title) == ["First"])
        model.cancelQuickCapture()
    }
}

@MainActor
@Test func queuedCaptureReceiptDoesNotDismissAReopenedCapture() async throws {
    try await withWorkspace { model, root in
        model.beginQuickCapture()
        model.quickCaptureTitle = "Same title"
        let receipt = model.quickCaptureGeneration
        model.cancelQuickCapture()
        model.beginQuickCapture()
        model.quickCaptureTitle = "Same title"
        await model.createTask(title: "Same title", vaultSession: model.vaultSession, captureGeneration: receipt)
        #expect(model.quickCaptureTitle == "Same title")
        #expect(model.isQuickCapturePresented)
        let saved = try await VaultStore(root: root).snapshot()
        #expect(saved.tasks.count == 1)
        model.cancelQuickCapture()
    }
}

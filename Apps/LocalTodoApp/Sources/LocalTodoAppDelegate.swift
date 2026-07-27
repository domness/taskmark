import AppKit

@MainActor
final class LocalTodoAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: WorkspaceModel?
    private var isFinishingTermination = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.hasPendingDocumentChanges else { return .terminateNow }
        guard !isFinishingTermination else { return .terminateLater }
        isFinishingTermination = true
        Task {
            let saved = await model.flushTaskChanges()
            if !saved {
                model.errorMessage = "Fix conflicting or invalid task changes before quitting."
            }
            isFinishingTermination = false
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }
}

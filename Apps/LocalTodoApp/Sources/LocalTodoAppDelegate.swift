import AppKit

@MainActor
final class LocalTodoAppDelegate: NSObject, NSApplicationDelegate {
    weak var windows: WorkspaceWindows?
    private var isFinishingTermination = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let windows, windows.hasPendingChanges else { return .terminateNow }
        guard !isFinishingTermination else { return .terminateLater }
        isFinishingTermination = true
        Task {
            let saved = await windows.flushAll()
            isFinishingTermination = false
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }
}

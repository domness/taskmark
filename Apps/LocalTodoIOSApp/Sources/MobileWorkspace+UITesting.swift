import Foundation
import LocalTodoMarkdown

extension MobileWorkspace {
    static func forAppLaunch() -> MobileWorkspace {
        #if DEBUG
            guard let name = ProcessInfo.processInfo.environment["TASKMARK_UI_TEST_SESSION"],
                  UUID(uuidString: name) != nil,
                  let defaults = UserDefaults(suiteName: name) else { return MobileWorkspace() }
            return MobileWorkspace(
                bookmarks: MobileVaultBookmarkStore(defaults: defaults),
                sampleVaultURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(name).appendingPathComponent("Sample Vault")
            )
        #else
            return MobileWorkspace()
        #endif
    }

    func prepareUITestVaultIfRequested() async -> Bool {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-onboarding") {
                return true
            }
            guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return false }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("TaskmarkUITestVault")
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try VaultInitializer.initialize(at: url, timezone: "Europe/London")
                try await session.open(root: url)
                let todayPath = try await session.capture(title: "Today fixture", route: .today)
                _ = try await session.capture(title: "Review **carefully** with `code`", route: .today)
                _ = try await session.capture(title: "Inbox fixture", route: .inbox)
                if ProcessInfo.processInfo.arguments.contains("--ui-testing-incomplete") {
                    let taskURL = url.appendingPathComponent(todayPath.value)
                    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: taskURL.path)
                    try await session.refresh()
                }
                vaultName = url.lastPathComponent
                await refreshAppearance()
                return true
            } catch {
                errorMessage = error.localizedDescription
                return true
            }
        #else
            return false
        #endif
    }
}

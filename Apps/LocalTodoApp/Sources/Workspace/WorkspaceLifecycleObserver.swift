import AppKit

/// Owns notification tokens independently of the workspace's main-actor lifetime.
final class WorkspaceLifecycleObserver {
    private let notifications: [(NotificationCenter, NSObjectProtocol)]

    init(onChange: @escaping @Sendable () -> Void) {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        notifications = [
            (center, NSApplication.didBecomeActiveNotification),
            (center, NSNotification.Name.NSSystemClockDidChange),
            (center, NSNotification.Name.NSSystemTimeZoneDidChange),
            (workspace, NSWorkspace.didWakeNotification),
        ].map { center, name in
            (center, center.addObserver(forName: name, object: nil, queue: nil) { _ in onChange() })
        }
    }

    deinit {
        for (center, token) in notifications {
            center.removeObserver(token)
        }
    }
}

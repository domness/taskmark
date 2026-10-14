import CoreServices
import Foundation

/// FSEvents is an invalidation signal, never an authoritative list of changed entities.
/// Every callback (including dropped events and root changes) requests a full coordinated scan.
final class VaultChangeObserver {
    private let stream: FSEventStreamRef

    init(root: URL, onChange: @escaping @Sendable () -> Void) throws {
        let callback = Callback(onChange)
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(callback).toOpaque(),
            retain: { pointer in
                guard let pointer else { return nil }
                _ = Unmanaged<Callback>.fromOpaque(pointer).retain()
                return pointer
            },
            release: { pointer in
                guard let pointer else { return }
                Unmanaged<Callback>.fromOpaque(pointer).release()
            },
            copyDescription: nil
        )
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<Callback>.fromOpaque(info).takeUnretainedValue().onChange()
            },
            &context,
            [root.resolvingSymlinksInPath().path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)
        ) else { throw ObservationError.unavailable }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue(label: "Taskmark.vault-events", qos: .utility))
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            throw ObservationError.unavailable
        }
        self.stream = stream
    }

    deinit {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    private final class Callback: Sendable {
        let onChange: @Sendable () -> Void

        init(_ onChange: @escaping @Sendable () -> Void) {
            self.onChange = onChange
        }
    }

    enum ObservationError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "File change notifications are unavailable. Taskmark will check the vault once a minute and on activation."
        }
    }
}

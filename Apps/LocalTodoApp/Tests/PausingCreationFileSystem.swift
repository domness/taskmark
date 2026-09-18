import Foundation
import LocalTodoMarkdown

/// Pauses one selected operation so tests can exercise input arriving during real filesystem work.
final class PausingCreationFileSystem: VaultFileSystem, @unchecked Sendable {
    enum Operation { case create, replace, read }
    private let operation: Operation
    private let base = FoundationVaultFileSystem()
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var paused = false

    init(operation: Operation = .create) {
        self.operation = operation
    }

    var hasPaused: Bool {
        lock.withLock { paused }
    }

    func release() {
        gate.signal()
    }

    func coordinateMoving(from source: URL, to destination: URL, operation: (URL, URL) throws -> Void) throws {
        try base.coordinateMoving(from: source, to: destination, operation: operation)
    }

    func coordinateWriting(at url: URL, intent: VaultWriteIntent, operation: (URL) throws -> Void) throws {
        try base.coordinateWriting(at: url, intent: intent, operation: operation)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try base.contentsOfDirectory(at: url)
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    func exists(at url: URL) -> Bool {
        base.exists(at: url)
    }

    func isSymbolicLink(at url: URL) throws -> Bool {
        try base.isSymbolicLink(at: url)
    }

    func markdownFiles(in root: URL) throws -> [URL] {
        try base.markdownFiles(in: root)
    }

    func move(from source: URL, to destination: URL) throws {
        try base.move(from: source, to: destination)
    }

    func read(at url: URL) throws -> Data {
        pauseIfNeeded(.read)
        return try base.read(at: url)
    }

    func remove(at url: URL) throws {
        try base.remove(at: url)
    }

    func removeEmptyDirectory(at url: URL) throws {
        try base.removeEmptyDirectory(at: url)
    }

    func removeFile(at url: URL) throws {
        try base.removeFile(at: url)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        pauseIfNeeded(.replace)
        try base.writeAtomically(data, to: url)
    }

    func writeExclusively(_ data: Data, to url: URL) throws {
        pauseIfNeeded(.create)
        try base.writeExclusively(data, to: url)
    }

    private func pauseIfNeeded(_ operation: Operation) {
        guard self.operation == operation else { return }
        let shouldPause = lock.withLock {
            guard !paused else { return false }
            paused = true
            return true
        }
        if shouldPause {
            gate.wait()
        }
    }
}

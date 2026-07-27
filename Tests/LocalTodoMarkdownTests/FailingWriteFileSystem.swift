import Foundation
import LocalTodoMarkdown

final class FailingWriteFileSystem: VaultFileSystem, @unchecked Sendable {
    private let base: FoundationVaultFileSystem
    private let failureWrite: Int
    private let coordinatedURL: URL?
    private let lock = NSLock()
    private var writeCount = 0

    init(base: FoundationVaultFileSystem, failureWrite: Int, coordinatedURL: URL? = nil) {
        self.base = base
        self.failureWrite = failureWrite
        self.coordinatedURL = coordinatedURL
    }

    func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws {
        try base.coordinateWriting(at: url, intent: intent) { coordinatedURL in
            try operation(self.coordinatedURL ?? coordinatedURL)
        }
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

    func markdownFiles(in root: URL) throws -> [URL] {
        try base.markdownFiles(in: root)
    }

    func move(from source: URL, to destination: URL) throws {
        try base.move(from: source, to: destination)
    }

    func read(at url: URL) throws -> Data {
        try base.read(at: url)
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
        if shouldFailWrite() {
            throw TestFileSystemError.injectedFailure
        }
        try base.writeAtomically(data, to: url)
    }

    func writeExclusively(_ data: Data, to url: URL) throws {
        if shouldFailWrite() {
            throw TestFileSystemError.injectedFailure
        }
        try base.writeExclusively(data, to: url)
    }

    private func shouldFailWrite() -> Bool {
        lock.lock()
        writeCount += 1
        let shouldFail = writeCount == failureWrite
        lock.unlock()
        return shouldFail
    }
}

private enum TestFileSystemError: Error {
    case injectedFailure
}

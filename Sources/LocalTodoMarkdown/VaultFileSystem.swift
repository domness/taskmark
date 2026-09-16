import Foundation

public enum VaultWriteIntent: Equatable, Sendable {
    case replacing
    case deleting
}

public protocol VaultFileSystem: Sendable {
    func coordinateMoving(
        from source: URL,
        to destination: URL,
        operation: (URL, URL) throws -> Void
    ) throws
    func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func createDirectory(at url: URL) throws
    func exists(at url: URL) -> Bool
    /// Inspects the entry without following its final component, including dangling links.
    /// Returns false for missing entries; other metadata failures must throw.
    func isSymbolicLink(at url: URL) throws -> Bool
    func markdownFiles(in root: URL) throws -> [URL]
    func move(from source: URL, to destination: URL) throws
    func read(at url: URL) throws -> Data
    func remove(at url: URL) throws
    func removeEmptyDirectory(at url: URL) throws
    func removeFile(at url: URL) throws
    func writeAtomically(_ data: Data, to url: URL) throws
    func writeExclusively(_ data: Data, to url: URL) throws
}

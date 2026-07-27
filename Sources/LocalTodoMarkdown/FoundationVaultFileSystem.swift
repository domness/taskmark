import Darwin
import Foundation

public struct FoundationVaultFileSystem: VaultFileSystem {
    public init() {}

    public func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        let options: NSFileCoordinator.WritingOptions = switch intent {
        case .replacing: .forReplacing
        case .deleting: .forDeleting
        }
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
            do {
                try operation(coordinatedURL)
            } catch {
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }

    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )
    }

    public func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func markdownFiles(in root: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            throw VaultStoreError.inputOutput("Unable to enumerate vault")
        }

        var files = [URL]()
        for case let url as URL in enumerator {
            let relative = relativePath(of: url, in: root)
            if relative == ".localtodo" || relative.hasPrefix(".localtodo/") {
                enumerator.skipDescendants()
                continue
            }
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values.isRegularFile == true, url.pathExtension == "md" {
                files.append(url)
            }
        }
        return files.sorted { relativePath(of: $0, in: root) < relativePath(of: $1, in: root) }
    }

    public func move(from source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    public func read(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func remove(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func removeEmptyDirectory(at url: URL) throws {
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return rmdir(path)
        }
        if result != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    public func removeFile(at url: URL) throws {
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return unlink(path)
        }
        if result != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    public func writeAtomically(_ data: Data, to url: URL) throws {
        let temporaryURL = try writeTemporaryFile(data, beside: url)

        do {
            if exists(at: url) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            unlinkFile(at: temporaryURL)
            throw error
        }
    }

    public func writeExclusively(_ data: Data, to url: URL) throws {
        let temporaryURL = try writeTemporaryFile(data, beside: url)
        let result = temporaryURL.withUnsafeFileSystemRepresentation { sourcePath in
            url.withUnsafeFileSystemRepresentation { destinationPath in
                guard let sourcePath, let destinationPath else { return Int32(-1) }
                return renameatx_np(
                    AT_FDCWD,
                    sourcePath,
                    AT_FDCWD,
                    destinationPath,
                    UInt32(RENAME_EXCL)
                )
            }
        }
        if result != 0 {
            let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            unlinkFile(at: temporaryURL)
            throw error
        }
    }

    private func writeTemporaryFile(_ data: Data, beside url: URL) throws -> URL {
        let temporaryURL = url.deletingLastPathComponent()
            .appendingPathComponent(".localtodo-write-\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw VaultStoreError.inputOutput("Unable to create temporary file")
        }
        do {
            let handle = try FileHandle(forWritingTo: temporaryURL)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            return temporaryURL
        } catch {
            unlinkFile(at: temporaryURL)
            throw error
        }
    }

    private func unlinkFile(at url: URL) {
        try? removeFile(at: url)
    }

    private func relativePath(of url: URL, in root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else {
            return path
        }
        return String(path.dropFirst(rootPath.count + 1))
    }
}

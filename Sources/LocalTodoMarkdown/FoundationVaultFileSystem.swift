import Foundation

public struct FoundationVaultFileSystem: VaultFileSystem {
    public init() {}

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

    public func writeAtomically(_ data: Data, to url: URL) throws {
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

            if exists(at: url) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
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

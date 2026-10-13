import Foundation

/// Publishes a complete sample at a device-local location chosen by the app shell.
/// Existing vaults are opened as-is: sample edits are never reset or repaired.
public actor SampleVault {
    private let root: URL
    private let fileSystem: any VaultFileSystem

    public init(root: URL, fileSystem: any VaultFileSystem = FoundationVaultFileSystem()) {
        self.root = root.standardizedFileURL
        self.fileSystem = fileSystem
    }

    public func prepare(now: Date, calendar: Calendar) throws -> URL {
        guard try !fileSystem.isSymbolicLink(at: root) else {
            throw VaultStoreError.invalidVault("The sample vault must not be a symbolic link.")
        }
        if fileSystem.exists(at: root) {
            _ = try VaultScanner(root: root, fileSystem: fileSystem).loadConfiguration()
            return root
        }
        let files = try SampleVaultContent.files(now: now, calendar: calendar)
        let staging = root.deletingLastPathComponent()
            .appendingPathComponent(".sample-\(UUID().uuidString)", isDirectory: true)
        var written = [(URL, Data)]()
        let directories = [staging] + [".config", "Areas", "Projects", "Tasks"].map {
            staging.appendingPathComponent($0, isDirectory: true)
        }
        do {
            for directory in directories {
                try fileSystem.createDirectory(at: directory)
            }
            for (path, data) in files {
                let url = staging.appendingPathComponent(path)
                try fileSystem.writeExclusively(data, to: url)
                written.append((url, data))
            }
            try publish(staging)
        } catch {
            let creationError = error
            do {
                try cleanStaging(written: written, directories: directories)
            } catch {
                throw VaultStoreError.inputOutput(
                    "Could not prepare the sample: \(creationError.localizedDescription) "
                        + "Unfinished files remain at \(staging.path): \(error.localizedDescription)"
                )
            }
            throw creationError
        }
        return root
    }

    private func publish(_ staging: URL) throws {
        var published = false
        try fileSystem.coordinateMoving(from: staging, to: root) { source, destination in
            guard source.standardizedFileURL == staging.standardizedFileURL,
                  destination.standardizedFileURL == root
            else {
                throw VaultStoreError.inputOutput("The sample vault location changed. Try opening it again.")
            }
            // Exclusive directory rename prevents another window/process's vault being replaced.
            try fileSystem.move(from: source, to: destination)
            published = true
        }
        guard published
        else { throw VaultStoreError.inputOutput("The sample vault could not be published. Try again.") }
    }

    private func cleanStaging(written: [(URL, Data)], directories: [URL]) throws {
        for (url, data) in written.reversed() where fileSystem.exists(at: url) {
            guard try !fileSystem.isSymbolicLink(at: url), try fileSystem.read(at: url) == data else {
                throw VaultStoreError.inputOutput("An unfinished sample file changed and was preserved.")
            }
            try fileSystem.removeFile(at: url)
        }
        for directory in directories.reversed() where fileSystem.exists(at: directory) {
            try fileSystem.removeEmptyDirectory(at: directory)
        }
    }
}

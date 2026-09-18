import Foundation

enum CLIInstallationError: LocalizedError {
    case missingExecutable
    case sameLocation

    var errorDescription: String? {
        switch self {
        case .missingExecutable: "The bundled taskmark command is missing or is not executable. Reinstall Taskmark."
        case .sameLocation: "Choose a location outside the Taskmark app bundle."
        }
    }
}

/// Exports the signed standalone tool into a location authorized by the native Save panel.
enum CLIInstaller {
    static func bundledExecutable(in bundle: Bundle = .main) -> URL {
        bundle.bundleURL.appendingPathComponent("Contents/Helpers/taskmark")
    }

    static func install(from source: URL, to destination: URL) throws {
        let files = FileManager.default
        guard files.isExecutableFile(atPath: source.path) else { throw CLIInstallationError.missingExecutable }
        guard source.resolvingSymlinksInPath() != destination.resolvingSymlinksInPath() else {
            throw CLIInstallationError.sameLocation
        }
        let wrapper = try FileWrapper(regularFileWithContents: Data(contentsOf: source))
        wrapper.fileAttributes = [
            FileAttributeKey.type.rawValue: FileAttributeType.typeRegular.rawValue,
            FileAttributeKey.posixPermissions.rawValue: 0o755,
        ]
        var coordinationError: NSError?
        var writeError: (any Error)?
        // Foundation coordinates the Save-panel grant and atomic replacement within the sandbox.
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) {
            do {
                try wrapper.write(to: $0, options: .atomic, originalContentsURL: nil)
            } catch {
                writeError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let writeError {
            throw writeError
        }
    }
}

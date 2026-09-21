import Foundation

enum CLIInstallationError: LocalizedError {
    case missingExecutable
    case temporaryApplication
    case authorizationCancelled
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable: "The bundled taskmark command is missing or is not executable. Reinstall Taskmark."
        case .temporaryApplication: "Move Taskmark to Applications and open it there before enabling the CLI."
        case .authorizationCancelled: "CLI registration was canceled."
        case let .registrationFailed(message): message
        }
    }
}

/// Registers the bundled tool using the standard macOS administrator authorization dialog.
enum CLIInstaller {
    static let destination = URL(fileURLWithPath: "/usr/local/bin/taskmark")

    static func bundledExecutable(in bundle: Bundle = .main) -> URL {
        bundle.bundleURL.appendingPathComponent("Contents/Helpers/taskmark")
    }

    static func isRegistered(source: URL, destination: URL = destination) -> Bool {
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path) else {
            return false
        }
        return target == source.path && FileManager.default.isExecutableFile(atPath: destination.path)
    }

    static func setEnabled(_ enabled: Bool, source: URL) throws {
        if enabled {
            guard FileManager.default.isExecutableFile(atPath: source.path) else {
                throw CLIInstallationError.missingExecutable
            }
            guard !source.path.contains("/AppTranslocation/"), !source.path.hasPrefix("/Volumes/") else {
                throw CLIInstallationError.temporaryApplication
            }
            if isRegistered(source: source) {
                return
            }
        }
        let command = CLIRegistrationScript.command(enabled: enabled, source: source, destination: destination)
        let scriptSource = CLIRegistrationScript.authorizationScript(command: command)
        guard let script = NSAppleScript(source: scriptSource) else {
            throw CLIInstallationError.registrationFailed("Could not prepare CLI registration. Try reopening Taskmark.")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue == -128 {
                throw CLIInstallationError.authorizationCancelled
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Could not register the taskmark command."
            throw CLIInstallationError.registrationFailed(message)
        }
    }
}

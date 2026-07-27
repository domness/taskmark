import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct CLIContext {
    let options: GlobalOptions
    let root: URL
    let store: VaultStore

    init(options: GlobalOptions) throws {
        self.options = options
        root = try Self.resolveVault(options.vault)
        store = VaultStore(root: root)
    }

    func snapshot() async throws -> VaultSnapshot {
        try await store.snapshot()
    }

    func today(configuration: VaultConfiguration, now: Date = Date()) throws -> CalendarDate {
        let calendar = try calendar(configuration: configuration)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = components.year, let month = components.month, let day = components.day else {
            throw CLIError.message("Unable to determine today's date")
        }
        return try CalendarDate(year: year, month: month, day: day)
    }

    func calendar(configuration: VaultConfiguration) throws -> Calendar {
        let timezone: TimeZone
        if let identifier = configuration.timezone {
            guard let configured = TimeZone(identifier: identifier) else {
                throw CLIError.message("Invalid vault timezone: \(identifier)")
            }
            timezone = configured
        } else {
            timezone = .current
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    static func resolveVault(_ explicitPath: String?) throws -> URL {
        if let explicitPath {
            return URL(fileURLWithPath: explicitPath).standardizedFileURL
        }

        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
        while true {
            let manifest = candidate.appendingPathComponent(LocalTodoSchema.manifestPath)
            if FileManager.default.fileExists(atPath: manifest.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                break
            }
            candidate = parent
        }
        throw CLIError.message("No Local Todo vault found in the current directory or its ancestors")
    }
}

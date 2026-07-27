import ArgumentParser
import Foundation
import LocalTodoMarkdown

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init", abstract: "Initialize a vault.")

    @Argument(help: "Directory to initialize.")
    var directory = "."

    @Option(help: "IANA timezone identifier.")
    var timezone: String?

    @Flag(help: "Validate without writing.")
    var dryRun = false

    func run() throws {
        let root = URL(fileURLWithPath: directory).standardizedFileURL
        if !dryRun {
            try VaultInitializer.initialize(at: root, timezone: timezone)
        }
        print(dryRun ? "Would initialize \(root.path)" : "Initialized \(root.path)")
    }
}

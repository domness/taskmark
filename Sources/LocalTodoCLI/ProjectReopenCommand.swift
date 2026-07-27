import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct ProjectReopenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reopen", abstract: "Reopen a project.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String
    @Option var status = ProjectStatus.active.rawValue

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        guard let record = snapshot.projects[path] else {
            throw CLIError.message("Project not found: \(path.value)")
        }
        guard let status = ProjectStatus(rawValue: status) else {
            throw CLIError.message("Invalid project status: \(status)")
        }
        let updated = try ProjectTransition.reopen(record.value, status: status, now: Date())
        if !global.dryRun {
            _ = try await context.store.update(.project(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.project(updated), context: context, command: "project reopen", dryRun: global.dryRun)
    }
}

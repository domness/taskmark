import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct ProjectCompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "complete", abstract: "Complete a project.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        guard let record = snapshot.projects[path] else {
            throw CLIError.message("Project not found: \(path.value)")
        }
        let updated = try ProjectTransition.complete(record.value, now: Date())
        if !global.dryRun {
            _ = try await context.store.update(.project(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.project(updated), context: context, command: "project complete", dryRun: global.dryRun)
    }
}

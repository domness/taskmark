import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct ReopenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reopen", abstract: "Reopen a completed task.")

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Exact task path.") var path: String
    @Option(help: "Incomplete status to restore.") var status = TaskStatus.inbox.rawValue

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        let record = try TaskCommandSupport.record(at: path, in: snapshot)
        let updated = try TaskTransition.reopen(
            record.value,
            status: CLIParsing.taskStatus(status),
            now: Date()
        )
        if !global.dryRun {
            _ = try await context.store.update(.task(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.task(updated), context: context, command: "reopen", dryRun: global.dryRun)
    }
}

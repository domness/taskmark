import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct CompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "complete", abstract: "Complete a task.")

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Exact task path.") var path: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        let record = try TaskCommandSupport.record(at: path, in: snapshot)
        let now = Date()
        let updated = try TaskTransition.complete(
            record.value,
            now: now,
            today: context.today(configuration: snapshot.configuration, now: now),
            calendar: context.calendar(configuration: snapshot.configuration)
        )
        if !global.dryRun {
            _ = try await context.store.update(.task(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.task(updated), context: context, command: "complete", dryRun: global.dryRun)
    }
}

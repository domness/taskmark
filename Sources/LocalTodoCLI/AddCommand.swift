import ArgumentParser
import Foundation
import LocalTodoMarkdown

struct AddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a task.")

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Vault-relative task path.") var path: String
    @OptionGroup var input: TaskInputOptions

    func run() async throws {
        let context = try CLIContext(options: global)
        let task = try input.task(at: CLIParsing.path(path), now: Date())
        let snapshot = try await context.snapshot()
        try TaskCommandSupport.validateReferences(task, in: snapshot)
        if !global.dryRun {
            _ = try await context.store.create(.task(task))
        }
        try CLIPrinter.entity(.task(task), context: context, command: "add", dryRun: global.dryRun)
    }
}

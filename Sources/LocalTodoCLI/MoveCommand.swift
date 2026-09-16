import ArgumentParser
import Foundation
import LocalTodoMarkdown

struct MoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move a task without replacing existing files. Project and area moves are disabled."
    )

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Current exact path.") var source: String
    @Argument(help: "Destination exact path.") var destination: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let source = try CLIParsing.path(source)
        let destination = try CLIParsing.path(destination)
        if global.dryRun {
            try await context.store.validateMove(from: source, to: destination)
            let output = MoveOutput(source: source.value, destination: destination.value)
            if global.json {
                try CLIPrinter.json(output, context: context, command: "move", dryRun: true)
            } else {
                print("Would move \(source.value) to \(destination.value)")
            }
            return
        }
        _ = try await context.store.move(from: source, to: destination, now: Date())
        let output = MoveOutput(source: source.value, destination: destination.value)
        if global.json {
            try CLIPrinter.json(output, context: context, command: "move", dryRun: false)
        } else {
            print("Moved \(source.value) to \(destination.value)")
        }
    }
}

private struct MoveOutput: Encodable {
    let source: String
    let destination: String
}

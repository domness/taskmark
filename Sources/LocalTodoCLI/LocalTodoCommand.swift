import ArgumentParser

@main
struct LocalTodoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "localtodo",
        abstract: "Manage a Local Todo Markdown vault.",
        version: "0.1.0",
        subcommands: [SchemaCommand.self]
    )
}

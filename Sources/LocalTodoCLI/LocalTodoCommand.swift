import ArgumentParser

@main
struct LocalTodoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "localtodo",
        abstract: "Manage a Local Todo Markdown vault.",
        version: "0.1.0",
        subcommands: [
            InitCommand.self,
            AddCommand.self,
            ListCommand.self,
            ShowCommand.self,
            EditCommand.self,
            CompleteCommand.self,
            ReopenCommand.self,
            SearchCommand.self,
            FilterCommand.self,
            ProjectCommand.self,
            AreaCommand.self,
            MoveCommand.self,
            DoctorCommand.self,
            SchemaCommand.self,
        ]
    )

    static func main() async {
        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.contains("--json"), !(error is CleanExit), !(error is ExitCode) {
                CLIErrorRenderer.write(error, arguments: arguments)
            }
            exit(withError: error)
        }
    }
}

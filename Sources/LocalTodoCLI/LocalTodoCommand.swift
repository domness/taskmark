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
            ProjectCommand.self,
            AreaCommand.self,
            MoveCommand.self,
            DoctorCommand.self,
            SchemaCommand.self,
        ]
    )
}

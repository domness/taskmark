import ArgumentParser

struct ProjectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "project",
        abstract: "Manage projects.",
        subcommands: [
            ProjectAddCommand.self,
            ProjectListCommand.self,
            ProjectShowCommand.self,
            ProjectEditCommand.self,
            ProjectCompleteCommand.self,
            ProjectReopenCommand.self,
        ]
    )
}

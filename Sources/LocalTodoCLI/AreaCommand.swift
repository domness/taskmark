import ArgumentParser

struct AreaCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "area",
        abstract: "Manage areas.",
        subcommands: [
            AreaAddCommand.self,
            AreaListCommand.self,
            AreaShowCommand.self,
            AreaEditCommand.self,
            AreaArchiveCommand.self,
            AreaActivateCommand.self,
        ]
    )
}

import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "Vault root. Defaults to the nearest ancestor vault.")
    var vault: String?

    @Flag(name: .long, help: "Emit stable machine-readable JSON.")
    var json = false

    @Flag(name: .long, help: "Validate and preview a mutation without writing.")
    var dryRun = false
}

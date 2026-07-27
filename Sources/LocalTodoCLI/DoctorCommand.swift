import ArgumentParser
import LocalTodoMarkdown

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose vault problems without repairing files."
    )

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        let context = try CLIContext(options: global)
        let diagnostics = try await context.snapshot().diagnostics.map(DiagnosticOutput.init)
        if global.json {
            try CLIPrinter.json(
                DiagnosticListOutput(diagnostics: diagnostics, count: diagnostics.count),
                context: context,
                command: "doctor",
                dryRun: false
            )
        } else if diagnostics.isEmpty {
            print("No issues found")
        } else {
            for diagnostic in diagnostics {
                print(
                    "\(diagnostic.severity)\t\(diagnostic.kind)\t\(diagnostic.path ?? "vault")\t\(diagnostic.message)"
                )
            }
        }
        if !diagnostics.isEmpty {
            throw ExitCode(10)
        }
    }
}

private struct DiagnosticOutput: Encodable {
    let severity: String
    let kind: String
    let message: String
    let path: String?
    let field: String?
    let reference: String?

    init(_ diagnostic: VaultDiagnostic) {
        severity = diagnostic.severity.rawValue
        kind = diagnostic.kind.rawValue
        message = diagnostic.message
        path = diagnostic.path?.value
        field = diagnostic.field
        reference = diagnostic.reference?.value
    }
}

private struct DiagnosticListOutput: Encodable {
    let diagnostics: [DiagnosticOutput]
    let count: Int
}

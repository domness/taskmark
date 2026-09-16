import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct CLIErrorEnvelope: Encodable {
    let apiVersion = 1
    let ok = false
    let command: String
    let dryRun: Bool
    let error: CLIErrorDetail

    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
        case ok, command
        case dryRun = "dry_run"
        case error
    }
}

struct CLIErrorDetail: Encodable {
    let kind: String
    let message: String
}

enum CLIErrorRenderer {
    static func data(for error: Error, command: String, dryRun: Bool) throws -> Data {
        let envelope = CLIErrorEnvelope(
            command: command,
            dryRun: dryRun,
            error: CLIErrorDetail(kind: kind(for: error), message: LocalTodoCommand.message(for: error))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(envelope)
    }

    static func write(_ error: Error, arguments: [String]) {
        let commands = Set(LocalTodoCommand.configuration.subcommands.map { $0.configuration.commandName ?? "" })
        let command = arguments.first(where: commands.contains) ?? "localtodo"
        guard let data = try? data(for: error, command: command, dryRun: arguments.contains("--dry-run")) else {
            return
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func kind(for error: Error) -> String {
        if let error = error as? SavedFilterError {
            return error == .conflict ? "conflict" : "malformed_file"
        }
        if let error = error as? VaultStoreError {
            return kind(for: error)
        }
        return switch error {
        case is DomainValidationError, is ValidationError: "validation"
        case is MarkdownDocumentError, is EntityDocumentError: "malformed_file"
        default: "command_failed"
        }
    }

    private static func kind(for error: VaultStoreError) -> String {
        switch error {
        case .conflict: "conflict"
        case .destinationExists: "destination_exists"
        case .invalidVault: "invalid_vault"
        case .missingReference: "missing_reference"
        case .notFound: "not_found"
        case .pathMismatch: "path_mismatch"
        case .unsupportedSchema: "unsupported_schema"
        case .wrongEntityType: "wrong_entity_type"
        case .inputOutput: "io"
        }
    }
}

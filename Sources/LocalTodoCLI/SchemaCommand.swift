import ArgumentParser
import Foundation
import LocalTodoMarkdown

struct SchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Describe the supported vault schema."
    )

    @Flag(help: "Emit stable machine-readable JSON.")
    var json = false

    func run() throws {
        let summary = SchemaSummary(
            version: LocalTodoSchema.currentVersion,
            manifestPath: LocalTodoSchema.manifestPath,
            entityTypes: LocalTodoSchema.entityTypes,
            taskStatuses: LocalTodoSchema.taskStatuses,
            priorities: LocalTodoSchema.priorities
        )

        if json {
            try printJSON(summary)
        } else {
            print("Local Todo schema \(summary.version)")
            print("Manifest: \(summary.manifestPath)")
            print("Entity types: \(summary.entityTypes.joined(separator: ", "))")
            print("Task statuses: \(summary.taskStatuses.joined(separator: ", "))")
            print("Priorities: \(summary.priorities.joined(separator: ", ")) and none")
        }
    }

    private func printJSON(_ summary: SchemaSummary) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(summary)
        guard let output = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                summary,
                EncodingError.Context(codingPath: [], debugDescription: "Unable to encode UTF-8 output")
            )
        }
        print(output)
    }
}

private struct SchemaSummary: Encodable {
    let version: Int
    let manifestPath: String
    let entityTypes: [String]
    let taskStatuses: [String]
    let priorities: [String]
}

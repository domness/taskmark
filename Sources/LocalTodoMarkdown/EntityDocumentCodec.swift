import LocalTodoDomain

public enum EntityDocumentCodec {
    public static func decode(_ document: MarkdownDocument, at path: VaultPath) throws -> LocalTodoEntity {
        let type = try FrontmatterReader(document: document).requiredString(.type)
        switch type {
        case "task":
            return try .task(TaskDocumentCodec.decode(document, at: path))
        case "project":
            return try .project(ProjectDocumentCodec.decode(document, at: path))
        case "area":
            return try .area(AreaDocumentCodec.decode(document, at: path))
        default:
            throw EntityDocumentError.unsupportedEntityType(type)
        }
    }

    public static func encode(
        _ entity: LocalTodoEntity,
        preserving document: MarkdownDocument? = nil
    ) throws -> MarkdownDocument {
        switch entity {
        case let .task(task):
            TaskDocumentCodec.encode(task, preserving: document)
        case let .project(project):
            ProjectDocumentCodec.encode(project, preserving: document)
        case let .area(area):
            AreaDocumentCodec.encode(area, preserving: document)
        }
    }
}

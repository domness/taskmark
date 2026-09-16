import Foundation
import LocalTodoDomain

enum TaskDocumentCodec {
    static func decode(_ document: MarkdownDocument, at path: VaultPath) throws -> TodoTask {
        let reader = FrontmatterReader(document: document)
        let title = try reader.requiredString(.title)
        let status = try enumValue(TaskStatus.self, rawValue: reader.requiredString(.status), field: .status)
        let priority = try optionalEnum(TaskPriority.self, rawValue: reader.optionalString(.priority), field: .priority)
        let createdAt = try reader.requiredTimestamp(.createdAt)
        let updatedAt = try reader.requiredTimestamp(.updatedAt)

        do {
            return try TodoTask(
                path: path,
                title: title,
                status: status,
                priority: priority,
                scheduled: reader.date(.scheduled),
                deadline: reader.date(.deadline),
                project: reader.path(.project),
                area: reader.path(.area),
                tags: reader.strings(.tags),
                recurrence: RecurrenceDocumentCodec.decode(document.node(forKey: FrontmatterKey.recurrence.rawValue)),
                resetChecklistOnRepeat: reader.boolean(.resetChecklistOnRepeat, default: false),
                body: document.body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: reader.timestamp(.completedAt, required: false)
            )
        } catch let error as EntityDocumentError {
            throw error
        } catch let error as DomainValidationError {
            throw EntityDocumentError.invalidDomainValue(error)
        }
    }

    static func encode(_ task: TodoTask, preserving existing: MarkdownDocument?) -> MarkdownDocument {
        var document = existing ?? .create(fields: [], body: task.body)
        document.setNode(FrontmatterNodes.string("task"), forKey: FrontmatterKey.type.rawValue)
        document.setNode(FrontmatterNodes.string(task.title), forKey: FrontmatterKey.title.rawValue)
        document.setNode(FrontmatterNodes.string(task.status.rawValue), forKey: FrontmatterKey.status.rawValue)
        document.setNode(
            task.priority.map { FrontmatterNodes.string($0.rawValue) },
            forKey: FrontmatterKey.priority.rawValue
        )
        document.setNode(
            task.scheduled.map { FrontmatterNodes.string($0.description) },
            forKey: FrontmatterKey.scheduled.rawValue
        )
        document.setNode(
            task.deadline.map { FrontmatterNodes.string($0.description) },
            forKey: FrontmatterKey.deadline.rawValue
        )
        document.setNode(FrontmatterNodes.optionalString(task.project?.value), forKey: FrontmatterKey.project.rawValue)
        document.setNode(FrontmatterNodes.optionalString(task.area?.value), forKey: FrontmatterKey.area.rawValue)
        document.setNode(FrontmatterNodes.strings(task.tags), forKey: FrontmatterKey.tags.rawValue)
        document.setNode(RecurrenceDocumentCodec.encode(task.recurrence), forKey: FrontmatterKey.recurrence.rawValue)
        document.setNode(
            task.resetChecklistOnRepeat ? FrontmatterNodes.boolean(true) : nil,
            forKey: FrontmatterKey.resetChecklistOnRepeat.rawValue
        )
        document.setNode(FrontmatterNodes.date(task.createdAt), forKey: FrontmatterKey.createdAt.rawValue)
        document.setNode(FrontmatterNodes.date(task.updatedAt), forKey: FrontmatterKey.updatedAt.rawValue)
        document.setNode(FrontmatterNodes.optionalDate(task.completedAt), forKey: FrontmatterKey.completedAt.rawValue)
        document.setBody(task.body)
        return document
    }

    private static func enumValue<Value: RawRepresentable>(
        _: Value.Type,
        rawValue: String,
        field: FrontmatterKey
    ) throws -> Value where Value.RawValue == String {
        guard let value = Value(rawValue: rawValue) else {
            throw EntityDocumentError.invalidField(field.rawValue)
        }
        return value
    }

    private static func optionalEnum<Value: RawRepresentable>(
        _ type: Value.Type,
        rawValue: String?,
        field: FrontmatterKey
    ) throws -> Value? where Value.RawValue == String {
        guard let rawValue else {
            return nil
        }
        return try enumValue(type, rawValue: rawValue, field: field)
    }
}

import Foundation
import LocalTodoDomain

enum ProjectDocumentCodec {
    static func decode(_ document: MarkdownDocument, at path: VaultPath) throws -> Project {
        let reader = FrontmatterReader(document: document)
        let statusValue = try reader.requiredString(.status)
        guard let status = ProjectStatus(rawValue: statusValue) else {
            throw EntityDocumentError.invalidField(FrontmatterKey.status.rawValue)
        }
        let createdAt = try reader.requiredTimestamp(.createdAt)
        let updatedAt = try reader.requiredTimestamp(.updatedAt)

        do {
            return try Project(
                path: path,
                title: reader.requiredString(.title),
                status: status,
                area: reader.path(.area),
                tags: reader.strings(.tags),
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

    static func encode(_ project: Project, preserving existing: MarkdownDocument?) -> MarkdownDocument {
        var document = existing ?? .create(fields: [], body: project.body)
        document.setNode(FrontmatterNodes.string("project"), forKey: FrontmatterKey.type.rawValue)
        document.setNode(FrontmatterNodes.string(project.title), forKey: FrontmatterKey.title.rawValue)
        document.setNode(FrontmatterNodes.string(project.status.rawValue), forKey: FrontmatterKey.status.rawValue)
        document.setNode(FrontmatterNodes.optionalString(project.area?.value), forKey: FrontmatterKey.area.rawValue)
        document.setNode(FrontmatterNodes.strings(project.tags), forKey: FrontmatterKey.tags.rawValue)
        document.setNode(FrontmatterNodes.date(project.createdAt), forKey: FrontmatterKey.createdAt.rawValue)
        document.setNode(FrontmatterNodes.date(project.updatedAt), forKey: FrontmatterKey.updatedAt.rawValue)
        document.setNode(
            FrontmatterNodes.optionalDate(project.completedAt),
            forKey: FrontmatterKey.completedAt.rawValue
        )
        document.setBody(project.body)
        return document
    }
}

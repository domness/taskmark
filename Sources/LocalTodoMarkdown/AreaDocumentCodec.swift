import Foundation
import LocalTodoDomain

enum AreaDocumentCodec {
    static func decode(_ document: MarkdownDocument, at path: VaultPath) throws -> Area {
        let reader = FrontmatterReader(document: document)
        let statusValue = try reader.requiredString(.status)
        guard let status = AreaStatus(rawValue: statusValue) else {
            throw EntityDocumentError.invalidField(FrontmatterKey.status.rawValue)
        }
        let createdAt = try reader.requiredTimestamp(.createdAt)
        let updatedAt = try reader.requiredTimestamp(.updatedAt)

        do {
            return try Area(
                path: path,
                title: reader.requiredString(.title),
                status: status,
                tags: reader.strings(.tags),
                body: document.body,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        } catch let error as EntityDocumentError {
            throw error
        } catch let error as DomainValidationError {
            throw EntityDocumentError.invalidDomainValue(error)
        }
    }

    static func encode(_ area: Area, preserving existing: MarkdownDocument?) -> MarkdownDocument {
        var document = existing ?? .create(fields: [], body: area.body)
        document.setNode(FrontmatterNodes.string("area"), forKey: FrontmatterKey.type.rawValue)
        document.setNode(FrontmatterNodes.string(area.title), forKey: FrontmatterKey.title.rawValue)
        document.setNode(FrontmatterNodes.string(area.status.rawValue), forKey: FrontmatterKey.status.rawValue)
        document.setNode(FrontmatterNodes.strings(area.tags), forKey: FrontmatterKey.tags.rawValue)
        document.setNode(FrontmatterNodes.date(area.createdAt), forKey: FrontmatterKey.createdAt.rawValue)
        document.setNode(FrontmatterNodes.date(area.updatedAt), forKey: FrontmatterKey.updatedAt.rawValue)
        document.setBody(area.body)
        return document
    }
}

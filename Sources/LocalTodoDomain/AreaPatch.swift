import Foundation

public struct AreaPatch: Equatable, Sendable {
    public var title: FieldUpdate<String> = .unchanged
    public var status: FieldUpdate<AreaStatus> = .unchanged
    public var tags: FieldUpdate<[String]> = .unchanged
    public var body: FieldUpdate<String> = .unchanged

    public init() {}

    public func applying(to area: Area, now: Date) throws -> Area {
        try Area(
            path: area.path,
            title: title.resolve(area.title),
            status: status.resolve(area.status),
            tags: tags.resolve(area.tags),
            body: body.resolve(area.body),
            createdAt: area.createdAt,
            updatedAt: now
        )
    }
}

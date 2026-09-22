import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct TaskDragItem: Codable, Transferable, Sendable {
    let path: String
    let vaultSession: UUID
    var reorder: TaskDragOrder?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .localTodoTaskReference)
            .visibility(.ownProcess)
    }
}

extension UTType {
    static let localTodoTaskReference = UTType(exportedAs: "com.domness.localtodo.task-reference")
}

struct TaskDragOrder: Codable, Sendable {
    let route: String
    let grouping: String
    let visiblePaths: [String]
    let sectionPaths: [String]

    init(context: TaskReorderContext) {
        route = context.route.listPreferencesKey
        grouping = context.grouping.rawValue
        visiblePaths = context.visiblePaths.map(\.value)
        sectionPaths = context.sectionPaths.map(\.value)
    }

    func matches(_ context: TaskReorderContext) -> Bool {
        route == context.route.listPreferencesKey && grouping == context.grouping.rawValue
            && visiblePaths == context.visiblePaths.map(\.value)
            && sectionPaths == context.sectionPaths.map(\.value)
    }
}

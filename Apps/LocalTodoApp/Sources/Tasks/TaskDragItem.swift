import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct TaskDragItem: Codable, Transferable {
    let path: String
    let vaultSession: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .localTodoTaskReference)
            .visibility(.ownProcess)
    }
}

private extension UTType {
    static let localTodoTaskReference = UTType(exportedAs: "com.domness.localtodo.task-reference")
}

import Foundation
import LocalTodoWorkspace

extension MobileWorkspace {
    static func defaultCheckpointStore() -> TaskDraftCheckpointStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return TaskDraftCheckpointStore(fileURL: base.appendingPathComponent("Taskmark/drafts.json"))
    }

    static func defaultCaptureCheckpointStore() -> CaptureDraftCheckpointStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return CaptureDraftCheckpointStore(fileURL: base.appendingPathComponent("Taskmark/capture-drafts.json"))
    }

    static func defaultCollectionCheckpointStore() -> CollectionDraftCheckpointStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return CollectionDraftCheckpointStore(fileURL: base.appendingPathComponent("Taskmark/collection-drafts.json"))
    }

    static func defaultFilterCheckpointStore() -> FilterDraftCheckpointStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FilterDraftCheckpointStore(fileURL: base.appendingPathComponent("Taskmark/filter-drafts.json"))
    }
}

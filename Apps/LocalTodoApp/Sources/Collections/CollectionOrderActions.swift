import LocalTodoDomain
import SwiftUI

struct CollectionOrderActions: View {
    let model: WorkspaceModel
    let path: VaultPath
    let collection: SidebarCollection

    var body: some View {
        let paths = model.orderedCollectionPaths(collection)
        Button("Move Up") { model.moveCollection(path, in: collection, offset: -1) }
            .disabled(paths.first == path || !paths.contains(path))
        Button("Move Down") { model.moveCollection(path, in: collection, offset: 1) }
            .disabled(paths.last == path || !paths.contains(path))
        Button("Restore Default Order") { model.resetSidebarOrder(collection) }
    }
}

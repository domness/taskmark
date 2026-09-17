import CoreTransferable
import Foundation
import LocalTodoDomain
import UniformTypeIdentifiers

enum SidebarCollection: String, Codable {
    case project, area
}

struct CollectionDragItem: Codable, Transferable {
    let path: String
    let collection: SidebarCollection
    let session: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "com.domness.localtodo.collection-reference"))
            .visibility(.ownProcess)
    }
}

enum SidebarDragItem: Transferable {
    case task(TaskDragItem)
    case collection(CollectionDragItem)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(importing: { (item: TaskDragItem) in Self.task(item) })
        ProxyRepresentation(importing: { (item: CollectionDragItem) in Self.collection(item) })
    }
}

enum SidebarOrder {
    static func sorted(_ paths: [VaultPath], order: [String]) -> [VaultPath] {
        let positions = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: min)
        return paths.sorted {
            let lhs = positions[$0.value] ?? Int.max
            let rhs = positions[$1.value] ?? Int.max
            return lhs == rhs ? $0.value < $1.value : lhs < rhs
        }
    }
}

extension WorkspaceModel {
    func orderedCollectionPaths(_ collection: SidebarCollection) -> [VaultPath] {
        let paths: [VaultPath] = switch collection {
        case .project: activeProjects.map(\.path)
        case .area: snapshot.map { Array($0.areas.keys) } ?? []
        }
        return SidebarOrder.sorted(paths, order: sidebarOrders[collection.rawValue] ?? [])
    }

    func loadSidebarOrder() {
        sidebarOrders = sidebarPreferences.dictionary(forKey: sidebarOrderKey) as? [String: [String]] ?? [:]
    }

    func moveCollection(_ path: VaultPath, in collection: SidebarCollection, offset: Int) {
        var paths = orderedCollectionPaths(collection)
        guard let index = paths.firstIndex(of: path), paths.indices.contains(index + offset) else { return }
        paths.swapAt(index, index + offset)
        saveSidebarOrder(paths.map(\.value), collection: collection)
    }

    func reorderCollection(
        _ item: CollectionDragItem,
        before path: VaultPath,
        in collection: SidebarCollection
    ) -> Bool {
        var paths = orderedCollectionPaths(collection)
        guard item.session == vaultSession, item.collection == collection,
              let source = try? VaultPath(item.path), source != path,
              paths.contains(source), paths.contains(path) else { return false }
        paths.removeAll { $0 == source }
        guard let index = paths.firstIndex(of: path) else { return false }
        paths.insert(source, at: index)
        saveSidebarOrder(paths.map(\.value), collection: collection)
        return true
    }

    func resetSidebarOrder(_ collection: SidebarCollection) {
        saveSidebarOrder([], collection: collection)
    }

    private var sidebarOrderKey: String {
        "sidebar-order." + (rootURL?.standardizedFileURL.path ?? "")
    }

    private func saveSidebarOrder(_ order: [String], collection: SidebarCollection) {
        sidebarOrders[collection.rawValue] = order
        sidebarPreferences.set(sidebarOrders, forKey: sidebarOrderKey)
    }
}

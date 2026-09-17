import Foundation
import LocalTodoDomain

enum SidebarCollection: String, Codable {
    case project, area
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

    func moveCollections(
        from offsets: IndexSet,
        to destination: Int,
        in collection: SidebarCollection,
        paths: [VaultPath],
        session: UUID
    ) -> Bool {
        guard session == vaultSession, paths == orderedCollectionPaths(collection),
              !offsets.isEmpty, offsets.allSatisfy(paths.indices.contains),
              (0 ... paths.count).contains(destination) else { return false }
        let moved = offsets.map { paths[$0] }
        var remaining = paths.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let insertion = destination - offsets.filter { $0 < destination }.count
        remaining.insert(contentsOf: moved, at: insertion)
        guard remaining != paths else { return false }
        saveSidebarOrder(remaining.map(\.value), collection: collection)
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

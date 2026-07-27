import Foundation

struct VaultBookmarkStore {
    private let key = "LocalTodoVaultBookmark"

    func save(_ url: URL) throws {
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil)
        UserDefaults.standard.set(data, forKey: key)
    }

    func restore() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        var isStale = false
        return try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}

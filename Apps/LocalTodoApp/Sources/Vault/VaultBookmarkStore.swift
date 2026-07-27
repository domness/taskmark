import Foundation

struct VaultBookmarkStore {
    private let key = "LocalTodoVaultBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ url: URL) throws {
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil)
        defaults.set(data, forKey: key)
    }

    func restore() throws -> URL? {
        guard let data = defaults.data(forKey: key) else {
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

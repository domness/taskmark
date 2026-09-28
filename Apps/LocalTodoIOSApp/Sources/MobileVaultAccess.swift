import Foundation

struct MobileVaultBookmarkStore {
    private static let key = "taskmark.mobile.vaultBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ url: URL) throws {
        let data = try url.bookmarkData(options: .minimalBookmark)
        defaults.set(data, forKey: Self.key)
    }

    func restore() throws -> URL? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            try save(url)
        }
        return url
    }
}

@MainActor
final class MobileVaultLease {
    let url: URL
    private let hasScopedAccess: Bool

    init(url: URL) {
        self.url = url.standardizedFileURL
        hasScopedAccess = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if hasScopedAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

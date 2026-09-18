import Foundation

public struct VaultPath: Codable, Hashable, Sendable {
    public let value: String

    public init(_ value: String) throws {
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        let isInvalid = normalized.hasPrefix("/")
            || normalized.hasSuffix("/")
            || !normalized.hasSuffix(".md")
            || normalized.contains("\0")
            || components.first?.lowercased() == ".config"
            || components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })

        guard !isInvalid else {
            throw DomainValidationError.invalidVaultPath
        }

        self.value = normalized
    }
}

extension VaultPath: CustomStringConvertible {
    public var description: String {
        value
    }
}

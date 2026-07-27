import CryptoKit
import Foundation

public struct FileRevision: Equatable, Hashable, Sendable {
    public let value: String

    public init(data: Data) {
        value = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

import Foundation
import SwiftUI

struct VaultAppearance: Equatable {
    var light = [String: String]()
    var dark = [String: String]()

    static let colorTokens: Set<String> = ["--accent", "--priority-1", "--priority-2", "--priority-3"]
    static let numberTokens: [String: ClosedRange<Double>] = ["--task-font-size": 11 ... 24, "--row-spacing": 2 ... 16]

    static func parse(_ source: String) throws -> Self {
        let source = source.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
        var result = Self()
        var remainder = source[...]
        while !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let open = remainder.firstIndex(of: "{"), let close = remainder.firstIndex(of: "}"),
                  open < close
            else {
                throw AppearanceError.invalid("Expected selector { declarations }.")
            }
            let selector = remainder[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
            guard [":root", ":root[data-appearance=light]", ":root[data-appearance=dark]"].contains(selector) else {
                throw AppearanceError.invalid("Unsupported selector: \(selector)")
            }
            for declaration in remainder[remainder.index(after: open) ..< close].split(separator: ";") {
                if declaration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                let parts = declaration.split(separator: ":", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard parts.count == 2 else { throw AppearanceError.invalid("Expected token: value;") }
                try validate(parts[0], value: parts[1])
                if selector != ":root[data-appearance=dark]" {
                    result.light[parts[0]] = parts[1]
                }
                if selector != ":root[data-appearance=light]" {
                    result.dark[parts[0]] = parts[1]
                }
            }
            remainder = remainder[remainder.index(after: close)...]
        }
        return result
    }

    private static func validate(_ token: String, value: String) throws {
        if colorTokens.contains(token), value.range(of: #"^#[0-9a-fA-F]{6}$"#, options: .regularExpression) != nil {
            return
        }
        if let range = numberTokens[token], value.hasSuffix("px"), let number = Double(value.dropLast(2)) {
            if range.contains(number) {
                return
            }
        }
        throw AppearanceError.invalid("Unsupported token or value: \(token): \(value)")
    }

    func color(_ token: String, scheme: ColorScheme, fallback: Color) -> Color {
        guard let value = (scheme == .dark ? dark : light)[token],
              let hex = UInt32(value.dropFirst(), radix: 16) else { return fallback }
        return Color(
            .sRGB,
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255,
            opacity: 1
        )
    }

    func number(_ token: String, scheme: ColorScheme, fallback: Double) -> Double {
        guard let value = (scheme == .dark ? dark : light)[token], let number = Double(value.dropLast(2)) else {
            return fallback
        }
        return number
    }
}

enum AppearanceError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message): "Stylesheet: \(message) Built-in appearance is in use."
        }
    }
}

extension WorkspaceModel {
    var effectiveAppearance: VaultAppearance {
        usesVaultStylesheet ? vaultAppearance : VaultAppearance()
    }

    func refreshAppearance() async {
        guard let store else { return }
        let session = vaultSession
        do {
            let source = try await store.stylesheet()
            let appearance = try source.map(VaultAppearance.parse) ?? VaultAppearance()
            guard session == vaultSession else { return }
            vaultAppearance = appearance
            stylesheetDiagnostic = nil
        } catch {
            guard session == vaultSession else { return }
            vaultAppearance = VaultAppearance()
            stylesheetDiagnostic = error.localizedDescription
        }
    }
}

import Foundation
import SwiftUI

public enum TaskmarkTheme: String, CaseIterable, Identifiable, Sendable {
    case standard, slate, forest, sand, catppuccin, dracula

    public var id: String {
        rawValue
    }

    public var title: String {
        self == .standard ? "Taskmark" : rawValue.capitalized
    }

    public var summary: String {
        switch self {
        case .standard: "Quiet neutrals"
        case .slate: "Cool blue-gray"
        case .forest: "Soft green"
        case .sand: "Warm earth"
        case .catppuccin: "Latte / Mocha"
        case .dracula: "Alucard / Dracula"
        }
    }

    public var tokens: TaskmarkAppearance {
        switch self {
        case .standard: palette(
                light: ["#f7f8fa", "#edf0f3", "#f1f3f6", "#365f99"],
                dark: ["#202226", "#191b1f", "#25282d", "#92b8ee"]
            )
        case .slate: palette(
                light: ["#f1f5f9", "#e4ebf3", "#eaf0f7", "#315e9d"],
                dark: ["#1c2532", "#151d29", "#232e3d", "#91bdf4"]
            )
        case .forest: palette(
                light: ["#f2f7f3", "#e4ede6", "#ebf2ed", "#306b49"],
                dark: ["#1d2922", "#162019", "#25332a", "#91c9a3"]
            )
        case .sand: palette(
                light: ["#faf6ef", "#efe7da", "#f4ede2", "#8b562c"],
                dark: ["#2b2520", "#211c17", "#342d25", "#dfb486"]
            )
        case .catppuccin: palette(
                light: ["#eff1f5", "#dce0e8", "#e6e9ef", "#8839ef"],
                dark: ["#1e1e2e", "#11111b", "#181825", "#cba6f7"]
            )
        case .dracula: palette(
                light: ["#fffbeb", "#f4f0e1", "#f8f4e5", "#644ac9"],
                dark: ["#282a36", "#22242e", "#2e303d", "#bd93f9"]
            )
        }
    }

    public var fontFamily: String? {
        switch self {
        case .catppuccin: "Figtree"
        case .dracula: "Inter"
        default: nil
        }
    }

    private func palette(light: [String], dark: [String]) -> TaskmarkAppearance {
        let keys = ["--background", "--sidebar-background", "--inspector-background", "--accent"]
        let size = self == .catppuccin ? "14px" : "13px"
        return TaskmarkAppearance(
            light: Dictionary(uniqueKeysWithValues: zip(keys, light))
                .merging(["--task-font-size": size]) { _, value in value },
            dark: Dictionary(uniqueKeysWithValues: zip(keys, dark))
                .merging(["--task-font-size": size]) { _, value in value }
        )
    }
}

public struct TaskmarkAppearance: Equatable, Sendable {
    public var light: [String: String]
    public var dark: [String: String]

    public init(light: [String: String] = [:], dark: [String: String] = [:]) {
        self.light = light
        self.dark = dark
    }

    public static func parse(_ source: String) throws -> Self {
        let source = source.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
        var result = Self()
        var remainder = source[...]
        while !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let open = remainder.firstIndex(of: "{"), let close = remainder.firstIndex(of: "}"),
                  open < close
            else {
                throw TaskmarkAppearanceError.invalid("Expected selector { declarations }.")
            }
            let selector = remainder[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
            guard [":root", ":root[data-appearance=light]", ":root[data-appearance=dark]"].contains(selector) else {
                throw TaskmarkAppearanceError.invalid("Unsupported selector: \(selector)")
            }
            for declaration in remainder[remainder.index(after: open) ..< close].split(separator: ";") {
                if declaration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                let parts = declaration.split(separator: ":", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard parts.count == 2 else { throw TaskmarkAppearanceError.invalid("Expected token: value;") }
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

    public func color(_ token: String, scheme: ColorScheme, fallback: Color) -> Color {
        guard let value = (scheme == .dark ? dark : light)[token], let hex = UInt32(value.dropFirst(), radix: 16) else {
            return fallback
        }
        return Color(
            .sRGB,
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255,
            opacity: 1
        )
    }

    public func number(_ token: String, scheme: ColorScheme, fallback: Double) -> Double {
        guard let value = (scheme == .dark ? dark : light)[token],
              let number = Double(value.dropLast(2)) else { return fallback }
        return number
    }

    public func overriding(with other: Self) -> Self {
        Self(
            light: light.merging(other.light) { _, value in value },
            dark: dark.merging(other.dark) { _, value in value }
        )
    }

    private static func validate(_ token: String, value: String) throws {
        let colors: Set = [
            "--accent",
            "--priority-1",
            "--priority-2",
            "--priority-3",
            "--background",
            "--sidebar-background",
            "--inspector-background",
        ]
        let numbers: [String: ClosedRange<Double>] = ["--task-font-size": 11 ... 24, "--row-spacing": 2 ... 16]
        if colors.contains(token), value.range(of: #"^#[0-9a-fA-F]{6}$"#, options: .regularExpression) != nil {
            return
        }
        if let range = numbers[token], value.hasSuffix("px") {
            if let number = Double(value.dropLast(2)), range.contains(number) {
                return
            }
        }
        throw TaskmarkAppearanceError.invalid("Unsupported token or value: \(token): \(value)")
    }
}

public enum TaskmarkAppearanceError: LocalizedError {
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case let .invalid(message): "Stylesheet: \(message) The selected built-in theme is in use."
        }
    }
}

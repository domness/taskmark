import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Native surface tokens, not browser layout rules. Each palette defines both appearances;
/// a valid vault stylesheet overrides individual tokens after the selected palette.
enum AppTheme: String, CaseIterable, Identifiable {
    case standard, slate, forest, sand
    var id: String {
        rawValue
    }

    var title: String {
        self == .standard ? "Taskmark" : rawValue.capitalized
    }

    var summary: String {
        switch self {
        case .standard: "Quiet neutrals"
        case .slate: "Cool blue-gray"
        case .forest: "Soft green"
        case .sand: "Warm earth"
        }
    }

    var tokens: VaultAppearance {
        switch self {
        case .standard:
            palette(
                light: ["#f7f8fa", "#edf0f3", "#f1f3f6", "#365f99"],
                dark: ["#202226", "#191b1f", "#25282d", "#92b8ee"]
            )
        case .slate:
            palette(
                light: ["#f1f5f9", "#e4ebf3", "#eaf0f7", "#315e9d"],
                dark: ["#1c2532", "#151d29", "#232e3d", "#91bdf4"]
            )
        case .forest:
            palette(
                light: ["#f2f7f3", "#e4ede6", "#ebf2ed", "#306b49"],
                dark: ["#1d2922", "#162019", "#25332a", "#91c9a3"]
            )
        case .sand:
            palette(
                light: ["#faf6ef", "#efe7da", "#f4ede2", "#8b562c"],
                dark: ["#2b2520", "#211c17", "#342d25", "#dfb486"]
            )
        }
    }

    private func palette(light: [String], dark: [String]) -> VaultAppearance {
        let keys = ["--background", "--sidebar-background", "--inspector-background", "--accent"]
        return VaultAppearance(
            light: Dictionary(uniqueKeysWithValues: zip(keys, light)),
            dark: Dictionary(uniqueKeysWithValues: zip(keys, dark))
        )
    }
}

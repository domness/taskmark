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
    case standard, slate, forest, sand, catppuccin, dracula
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
        case .catppuccin: "Latte / Mocha"
        case .dracula: "Alucard / Dracula"
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
        case .catppuccin:
            // Upstream Base, Crust, Mantle and Mauve; see docs/THEMES.md for attribution.
            palette(
                light: ["#eff1f5", "#dce0e8", "#e6e9ef", "#8839ef"],
                dark: ["#1e1e2e", "#11111b", "#181825", "#cba6f7"]
            )
        case .dracula:
            // Upstream backgrounds/purple accents with native pane adaptations documented in THEMES.md.
            palette(
                light: ["#fffbeb", "#f4f0e1", "#f8f4e5", "#644ac9"],
                dark: ["#282a36", "#22242e", "#2e303d", "#bd93f9"]
            )
        }
    }

    private func palette(light: [String], dark: [String]) -> VaultAppearance {
        let keys = ["--background", "--sidebar-background", "--inspector-background", "--accent"]
        return VaultAppearance(
            light: Dictionary(uniqueKeysWithValues: zip(keys, light))
                .merging(["--task-font-size": self == .catppuccin ? "14px" : "13px"]) { _, value in value },
            dark: Dictionary(uniqueKeysWithValues: zip(keys, dark))
                .merging(["--task-font-size": self == .catppuccin ? "14px" : "13px"]) { _, value in value }
        )
    }
}

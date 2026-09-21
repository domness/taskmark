import AppKit
import SwiftUI

struct ThemeSettingsView: View {
    @Bindable var model: WorkspaceModel
    @Bindable var preferences: AppPreferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Appearance").themeFont(.headline)
                    Picker("Appearance", selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("System follows your Mac’s light and dark appearance.")
                        .themeFont(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your themes").themeFont(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(AppTheme.allCases) { theme in
                            ThemePreview(theme: theme, scheme: scheme, isSelected: preferences.theme == theme) {
                                preferences.theme = theme
                            }
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Custom stylesheet").themeFont(.headline)
                    Toggle("Apply vault stylesheet", isOn: $preferences.usesVaultStylesheet)
                    Text(
                        "Customize colors and spacing in .config/style.css. Changes reload automatically."
                    )
                    .themeFont(.callout).foregroundStyle(.secondary)
                    if let diagnostic = model.stylesheetDiagnostic {
                        Label(diagnostic, systemImage: "exclamationmark.triangle").themeFont(.callout)
                    } else if model.snapshot == nil {
                        Text("Open a vault to load its custom stylesheet.").foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Reveal Vault") {
                            if let root = model.rootURL {
                                NSWorkspace.shared.activateFileViewerSelecting([root])
                            }
                        }
                        .disabled(model.rootURL == nil)
                        Button("Reload Stylesheet") { Task { await model.refreshAppearance() } }
                            .disabled(model.rootURL == nil)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .defaultScrollAnchor(.top, for: .alignment)
    }
}

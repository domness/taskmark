import SwiftUI

struct SettingsView: View {
    let model: WorkspaceModel
    let cliRegistration: CLIRegistration
    let updates: AppUpdates
    @State private var section: SettingsSection? = .general

    init(
        model: WorkspaceModel,
        initialSection: SettingsSection = .general,
        cliRegistration: CLIRegistration = CLIRegistration(),
        updates: AppUpdates = AppUpdates()
    ) {
        self.model = model
        self.cliRegistration = cliRegistration
        self.updates = updates
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsSection.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: 170)
            .themeSurface("--sidebar-background")
            Divider()
            Group {
                switch section ?? .general {
                case .general:
                    GeneralSettingsView(model: model, preferences: model.preferences, cliRegistration: cliRegistration)
                case .theme:
                    ThemeSettingsView(model: model, preferences: model.preferences)
                        .disabled(model.snapshot == nil)
                case .updates:
                    UpdatesSettingsView(updates: updates)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .themeSurface()
            .navigationTitle((section ?? .general).title)
        }
        .frame(minWidth: 700, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            if model.snapshot == nil, section != .updates {
                Text("Open a vault to edit its shared preferences.").padding()
            }
            ConfigurationSaveStatus(model: model)
        }
        .background {
            SettingsWindowResizing()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .task { await model.refreshConfigurationSettings() }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, theme, updates
    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .theme: "paintpalette"
        case .updates: "arrow.down.circle"
        }
    }
}

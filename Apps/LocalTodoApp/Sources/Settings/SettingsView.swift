import SwiftUI

struct SettingsView: View {
    let model: WorkspaceModel
    @State private var section: SettingsSection? = .general

    init(model: WorkspaceModel, initialSection: SettingsSection = .general) {
        self.model = model
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(ideal: 170)
            .themeSurface("--sidebar-background")
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralSettingsView(model: model, preferences: model.preferences)
                case .theme: ThemeSettingsView(model: model, preferences: model.preferences)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .themeSurface()
            .navigationTitle((section ?? .general).title)
        }
        .frame(minWidth: 700, idealWidth: 760, minHeight: 560, idealHeight: 620)
        .task { await model.refreshConfigurationSettings() }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, theme
    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var symbol: String {
        self == .general ? "gearshape" : "paintpalette"
    }
}

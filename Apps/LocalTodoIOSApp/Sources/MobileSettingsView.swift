import LocalTodoMarkdown
import LocalTodoPresentation
import SwiftUI

struct MobileSettingsView: View {
    let workspace: MobileWorkspace

    var body: some View {
        List {
            NavigationLink("General") { MobileGeneralSettingsView(workspace: workspace) }
            NavigationLink("Theme") { MobileThemeSettingsView(workspace: workspace) }
            NavigationLink("Vault") { MobileVaultSettingsView(workspace: workspace) }
        }
        .navigationTitle("Settings")
    }
}

private struct MobileGeneralSettingsView: View {
    let workspace: MobileWorkspace

    private var preferences: [String: ConfigurationValue] {
        workspace.snapshot?.configuration.preferences ?? [:]
    }

    var body: some View {
        Form {
            Picker("Start Screen", selection: stringBinding("initial_view", fallback: "today")) {
                ForEach(["today", "inbox", "next", "upcoming", "waiting", "someday", "all", "search"], id: \.self) {
                    Text($0.capitalized).tag($0)
                }
            }
            Picker("Week Starts", selection: integerBinding("week_start", fallback: 2)) {
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
            }
            Picker("Date Format", selection: stringBinding("date_format", fallback: "system")) {
                Text("System").tag("system")
                Text("ISO 8601").tag("iso")
                Text("Day / Month / Year").tag("dayFirst")
                Text("Month / Day / Year").tag("monthFirst")
            }
            Picker("Time Format", selection: stringBinding("time_format", fallback: "system")) {
                Text("System").tag("system")
                Text("12-hour").tag("twelveHour")
                Text("24-hour").tag("twentyFourHour")
            }
            Section("Calendar") {
                LabeledContent("Vault Time Zone", value: workspace.snapshot?.configuration.timezone ?? "System")
                Button("Use Current Time Zone") {
                    Task { _ = await workspace.setTimezone(TimeZone.current.identifier) }
                }
            }
        }
        .navigationTitle("General")
    }

    private func stringBinding(_ key: String, fallback: String) -> Binding<String> {
        Binding(
            get: {
                guard case let .string(value) = preferences[key] else { return fallback }
                return value
            },
            set: { value in Task { _ = await workspace.setPreferences([key: .string(value)]) } }
        )
    }

    private func integerBinding(_ key: String, fallback: Int) -> Binding<Int> {
        Binding(
            get: {
                guard case let .integer(value) = preferences[key] else { return fallback }
                return value
            },
            set: { value in Task { _ = await workspace.setPreferences([key: .integer(value)]) } }
        )
    }
}

private struct MobileThemeSettingsView: View {
    let workspace: MobileWorkspace

    var body: some View {
        Form {
            Picker("Appearance", selection: stringPreference("appearance", fallback: "system")) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Section("Palette") {
                ForEach(TaskmarkTheme.allCases) { theme in
                    Button {
                        Task { _ = await workspace.setPreferences(["theme": .string(theme.rawValue)]) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(theme.title)
                                Text(theme.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if workspace.theme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Vault Stylesheet") {
                Toggle("Use style.css", isOn: boolPreference("vault_stylesheet"))
                Button("Reload Stylesheet") { Task { await workspace.refresh() } }
                if let diagnostic = workspace.stylesheetDiagnostic {
                    Label(diagnostic, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Theme")
    }

    private func stringPreference(_ key: String, fallback: String) -> Binding<String> {
        Binding(
            get: {
                guard case let .string(value) = workspace.snapshot?.configuration.preferences[key]
                else { return fallback }
                return value
            },
            set: { value in Task { _ = await workspace.setPreferences([key: .string(value)]) } }
        )
    }

    private func boolPreference(_ key: String) -> Binding<Bool> {
        Binding(
            get: {
                guard case let .bool(value) = workspace.snapshot?.configuration.preferences[key] else { return false }
                return value
            },
            set: { value in Task { _ = await workspace.setPreferences([key: .bool(value)]) } }
        )
    }
}

private struct MobileVaultSettingsView: View {
    let workspace: MobileWorkspace

    var body: some View {
        Form {
            LabeledContent("Vault", value: workspace.vaultName ?? "Unavailable")
            if let root = workspace.session.rootURL {
                Text(root.path).font(.caption.monospaced()).textSelection(.enabled)
            }
            Button("Refresh") { Task { await workspace.refresh() } }
            Button("Switch Vault") { workspace.requestOpen() }
        }
        .navigationTitle("Vault")
    }
}

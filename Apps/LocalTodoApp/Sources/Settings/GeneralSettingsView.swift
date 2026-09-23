import SwiftUI

struct GeneralSettingsView: View {
    let model: WorkspaceModel
    @Bindable var preferences: AppPreferences
    let cliRegistration: CLIRegistration

    var body: some View {
        Form {
            Section("Calendar & Time") {
                Picker("Start week on", selection: $preferences.weekStart) {
                    ForEach(WeekStart.allCases) { Text($0.title).tag($0) }
                }
                Picker("Date format", selection: $preferences.dateFormat) {
                    ForEach(DisplayDateFormat.allCases) { Text($0.title).tag($0) }
                }
                Picker("Time format", selection: $preferences.timeFormat) {
                    ForEach(DisplayTimeFormat.allCases) { Text($0.title).tag($0) }
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    LabeledContent("Preview", value: model.formattedTimestamp(context.date))
                        .foregroundStyle(.secondary)
                }
                Text("Date display follows your preference. Exact date entry and Markdown files use YYYY-MM-DD.")
                    .themeFont(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.snapshot == nil)
            Section("Vault Time Zone") {
                if model.snapshot != nil {
                    TimezoneSetting(model: model)
                    Text("Applies to \(model.vaultName ?? "this vault"), including Today, recurring tasks and the CLI.")
                        .themeFont(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Open a vault to choose its time zone.").foregroundStyle(.secondary)
                }
            }
            .disabled(model.snapshot == nil)
            Section("Startup") {
                Picker("Initial view", selection: $preferences.initialView) {
                    ForEach(InitialView.allCases) { Text($0.title).tag($0) }
                }
                Text("Used when opening the app or switching vaults.")
                    .themeFont(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.snapshot == nil)
            Section("Dock") {
                Toggle("Badge", isOn: $preferences.showsDockBadge)
                    .toggleStyle(.switch)
                Text("Show the number of incomplete tasks scheduled or due today or earlier on the Dock icon.")
                    .themeFont(.caption).foregroundStyle(.secondary)
                Text("Matches Today in the most recently active vault. Hidden when the count is zero.")
                    .themeFont(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.snapshot == nil)
            CLISettingsSection(registration: cliRegistration)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .defaultScrollAnchor(.top, for: .alignment)
    }
}

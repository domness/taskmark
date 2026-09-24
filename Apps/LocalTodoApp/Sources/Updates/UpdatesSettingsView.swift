import SwiftUI

struct UpdatesSettingsView: View {
    @ObservedObject var updates: AppUpdates

    var body: some View {
        Form {
            Section("Taskmark") {
                LabeledContent("Version", value: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "Development")
                Text("Updates are downloaded from Taskmark’s GitHub Releases and verified before installation.")
                    .foregroundStyle(.secondary)
                if let url = URL(string: "https://github.com/domness/taskmark/releases") {
                    Link("View Releases on GitHub", destination: url)
                }
            }
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.setAutomaticallyChecksForUpdates($0) }
                ))
                .disabled(updates.startupError != nil)
                Text("Checks daily when enabled. You choose when to install. Applies only to this Mac.")
                    .foregroundStyle(.secondary)
                Button("Check for Updates…", action: updates.checkForUpdates)
                    .disabled(!updates.canCheckForUpdates)
                if let date = updates.lastUpdateCheckDate {
                    LabeledContent("Last checked") {
                        Text(date, format: .dateTime.day().month().year().hour().minute())
                    }
                }
                if let error = updates.startupError {
                    Label(error, systemImage: "exclamationmark.triangle")
                }
            }
        }
        .formStyle(.grouped)
        .task { updates.start() }
    }
}

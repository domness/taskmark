import SwiftUI

struct ConfigurationSaveStatus: View {
    let model: WorkspaceModel

    var body: some View {
        if let error = model.configurationSettingsError {
            VStack(alignment: .leading, spacing: 6) {
                Label(error, systemImage: "exclamationmark.triangle")
                HStack {
                    if !model.pendingPreferenceChanges.isEmpty {
                        Button("Use File Preferences") { Task { await model.discardPreferenceChanges() } }
                        if !model.preferenceConflicts.isEmpty {
                            Button("Keep My Preferences") { Task { await model.keepPreferenceChanges() } }
                        } else {
                            Button("Retry Saving") { Task { _ = await model.flushPreferences() } }
                        }
                    } else {
                        Button("Reload Configuration") { Task { await model.refreshConfigurationSettings() } }
                    }
                }
                .disabled(model.isSavingPreferences || model.isSavingConfiguration)
            }
            .font(.callout)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.isSavingPreferences || !model.pendingPreferenceChanges.isEmpty {
            Label("Saving vault preferences…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
    }
}

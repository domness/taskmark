import AppKit
import SwiftUI

struct CLISettingsSection: View {
    @Bindable var registration: CLIRegistration

    var body: some View {
        Section("Command Line") {
            Toggle("Command-line interface", isOn: Binding(
                get: { registration.isEnabled },
                set: { enabled in Task { await registration.setEnabled(enabled) } }
            ))
            .disabled(registration.isWorking)
            .accessibilityIdentifier("cli-enabled")
            Text(
                "Register taskmark in /usr/local/bin to use it from your terminal. "
                    + "macOS will ask for administrator permission."
            )
            .themeFont(.caption).foregroundStyle(.secondary)
            if registration.isWorking {
                ProgressView("Updating CLI registration…").controlSize(.small)
            } else if registration.isEnabled {
                Text("Registered. Open a new terminal and run taskmark --help.")
                    .themeFont(.caption).foregroundStyle(.secondary)
            }
        }
        .task { registration.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            registration.refresh()
        }
        .alert("Could Not Update Command-Line Interface", isPresented: Binding(
            get: { registration.errorMessage != nil },
            set: {
                if !$0 {
                    registration.errorMessage = nil
                }
            }
        )) {
            Button("OK") { registration.errorMessage = nil }
        } message: {
            Text(registration.errorMessage ?? "")
        }
    }
}

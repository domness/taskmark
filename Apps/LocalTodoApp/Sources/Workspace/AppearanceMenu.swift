import SwiftUI

struct AppearanceMenu: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        Section("Appearance") {
            Toggle("Use Vault Stylesheet", isOn: $model.usesVaultStylesheet)
            if let diagnostic = model.stylesheetDiagnostic {
                Button("Stylesheet Issue…") { model.errorMessage = diagnostic }
            }
        }
    }
}

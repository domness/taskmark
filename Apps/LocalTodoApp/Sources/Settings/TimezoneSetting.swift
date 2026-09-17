import SwiftUI

struct TimezoneSetting: View {
    let model: WorkspaceModel
    @State private var isPresented = false
    @State private var search = ""

    var body: some View {
        LabeledContent("Time zone") {
            if model.isSavingConfiguration {
                ProgressView().controlSize(.small)
            }
            Button(model.configurationSettings?.value.timezone ?? "System (\(TimeZone.current.identifier))") {
                search = ""
                isPresented = true
            }
            .disabled(model.isSavingConfiguration || model.configurationSettings == nil)
            .popover(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Find time zone", text: $search).textFieldStyle(.roundedBorder)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            zoneButton(nil)
                            ForEach(matchingZones, id: \.self) { zoneButton($0) }
                        }
                    }
                    Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                }
                .padding(16)
                .frame(width: 340, height: 380)
            }
        }
    }

    private var matchingZones: [String] {
        TimeZone.knownTimeZoneIdentifiers.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
    }

    private func zoneButton(_ identifier: String?) -> some View {
        Button {
            isPresented = false
            Task { await model.setVaultTimezone(identifier) }
        } label: {
            HStack {
                Text(identifier ?? "System (\(TimeZone.current.identifier))")
                Spacer()
                if model.configurationSettings?.value.timezone == identifier {
                    Image(systemName: "checkmark").accessibilityLabel("Selected")
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

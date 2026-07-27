import SwiftUI

struct QuickCaptureRow: View {
    let model: WorkspaceModel
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            TextField("Capture to Inbox", text: $title)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { submit() }
            Button("Cancel") { model.isQuickCapturePresented = false }
                .buttonStyle(.plain)
        }
        .onAppear { isFocused = true }
        .onExitCommand { model.isQuickCapturePresented = false }
    }

    private func submit() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let vaultSession = model.vaultSession
        Task { await model.createTask(title: value, vaultSession: vaultSession) }
    }
}

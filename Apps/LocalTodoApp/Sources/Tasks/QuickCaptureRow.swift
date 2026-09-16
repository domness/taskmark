import SwiftUI

struct QuickCaptureRow: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            TextField(model.capturePrompt, text: $model.quickCaptureTitle)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { submit() }
            Button("Cancel") { model.cancelQuickCapture() }
                .buttonStyle(.plain)
        }
        .onAppear { isFocused = true }
        .onExitCommand { model.cancelQuickCapture() }
    }

    private func submit() {
        let value = model.quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let vaultSession = model.vaultSession
        let route = model.quickCaptureRoute
        let generation = model.quickCaptureGeneration
        Task {
            await model.createTask(
                title: value,
                vaultSession: vaultSession,
                captureRoute: route,
                captureGeneration: generation
            )
        }
    }
}

import SwiftUI

struct WorkspaceWindowRoot: View {
    let windows: WorkspaceWindows
    @State private var model: WorkspaceModel

    init(windows: WorkspaceWindows, model: WorkspaceModel? = nil) {
        self.windows = windows
        _model = State(initialValue: model ?? WorkspaceModel(preferences: windows.preferences))
    }

    var body: some View {
        WorkspaceView(model: model)
            .modifier(AppAppearanceModifier(model: model))
            .focusedSceneValue(\.workspaceModel, model)
            .disabled(windows.isFlushingAll || model.isClosingWindow)
            .background {
                WorkspaceWindowLifecycle(model: model, windows: windows)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            .task { await windows.start(model) }
    }
}

private struct WorkspaceModelFocusKey: FocusedValueKey {
    typealias Value = WorkspaceModel
}

extension FocusedValues {
    var workspaceModel: WorkspaceModel? {
        get { self[WorkspaceModelFocusKey.self] }
        set { self[WorkspaceModelFocusKey.self] = newValue }
    }
}

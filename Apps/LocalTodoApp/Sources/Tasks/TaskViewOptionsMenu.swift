import LocalTodoDomain
import SwiftUI

struct TaskViewOptionsMenu: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        Menu {
            TaskSortPicker(model: model)
            Section("Show in Rows") {
                Toggle("Project", isOn: metadataBinding(.project))
                Toggle("Area", isOn: metadataBinding(.area))
                Toggle("Tags", isOn: metadataBinding(.tags))
            }
            AppearanceMenu(model: model)
            Picker("Group By", selection: groupingBinding) {
                ForEach(TaskListGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping)
                }
            }
        } label: {
            Label(
                "View Options",
                systemImage: model.stylesheetDiagnostic == nil
                    ? "line.3.horizontal.decrease" : "exclamationmark.triangle"
            )
            .frame(minWidth: 36, minHeight: 36)
            .contentShape(Rectangle())
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .frame(minWidth: 36, minHeight: 36)
        .help("Choose row details and grouping for this view")
    }

    private func metadataBinding(_ field: TaskListMetadataField) -> Binding<Bool> {
        Binding(
            get: {
                let options = model.currentTaskListDisplayOptions
                return switch field {
                case .project: options.showsProject
                case .area: options.showsArea
                case .tags: options.showsTags
                }
            },
            set: { model.setTaskListMetadata(field, isVisible: $0) }
        )
    }

    private var groupingBinding: Binding<TaskListGrouping> {
        Binding(
            get: { model.currentTaskListDisplayOptions.grouping },
            set: { model.setTaskListGrouping($0) }
        )
    }
}

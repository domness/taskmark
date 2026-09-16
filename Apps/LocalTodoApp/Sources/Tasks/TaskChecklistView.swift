import LocalTodoDomain
import SwiftUI

struct TaskChecklistView: View {
    let model: WorkspaceModel
    let draft: TaskDraft

    var body: some View {
        let checklist = MarkdownChecklist(draft.notes)
        if !checklist.items.isEmpty {
            Section("Checklist") {
                ForEach(checklist.items) { item in
                    Toggle(item.title.isEmpty ? "Untitled step" : item.title, isOn: Binding(
                        get: { item.isChecked },
                        set: { model.setChecklistItem(item, checked: $0, in: draft, projection: checklist) }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

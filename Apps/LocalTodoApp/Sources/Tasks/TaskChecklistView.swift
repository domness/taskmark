import LocalTodoDomain
import SwiftUI

struct TaskChecklistView: View {
    let model: WorkspaceModel
    let draft: TaskDraft
    @State private var newItemTitle = ""

    var body: some View {
        let checklist = MarkdownChecklist(draft.notes)
        InspectorPropertySection("Checklist") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(checklist.items) { item in
                    Toggle(item.title.isEmpty ? "Untitled step" : item.title, isOn: Binding(
                        get: { item.isChecked },
                        set: { model.setChecklistItem(item, checked: $0, in: draft, projection: checklist) }
                    ))
                    .toggleStyle(.checkbox)
                    .contextMenu {
                        Button("Delete Checklist Item", role: .destructive) {
                            model.removeChecklistItem(item, from: draft, projection: checklist)
                        }
                    }
                }
                HStack {
                    TextField("New checklist item", text: $newItemTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addItem)
                    Button("Add", systemImage: "plus", action: addItem)
                        .labelStyle(.iconOnly)
                        .help("Add checklist item")
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.leading, 26)
        }
    }

    private func addItem() {
        if model.addChecklistItem(newItemTitle, to: draft) {
            newItemTitle = ""
        }
    }
}

import SwiftUI

struct TaskTagsView: View {
    let model: WorkspaceModel
    let draft: TaskDraft
    @State private var isAdding = false
    @State private var entry = ""
    @FocusState private var isEntryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                Spacer()
                Button("Add Tag", systemImage: "plus") {
                    entry = ""
                    isAdding = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .popover(isPresented: $isAdding) { tagEntry }
            }
            TagFlowLayout {
                ForEach(draft.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).lineLimit(1).help(tag)
                        Button("Remove \(tag)", systemImage: "xmark") {
                            model.changeDraft(
                                draft,
                                keyPath: \.tags,
                                to: draft.tags.filter { $0 != tag },
                                actionName: "Remove Tag"
                            )
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                    }
                    .themeFont(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    private var tagEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Tag name", text: $entry)
                    .focused($isEntryFocused)
                    .onSubmit { add(entry) }
                Button("Add") { add(entry) }
                    .disabled(entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            let suggestions = model.allTags.filter {
                !draft.tags.contains($0) && (entry.isEmpty || $0.localizedCaseInsensitiveContains(entry))
            }
            if !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(suggestions, id: \.self) { tag in
                            Button(tag) { add(tag) }.buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding()
        .frame(width: 260)
        .onAppear { isEntryFocused = true }
    }

    private func add(_ input: String) {
        if model.addTag(input, to: draft) {
            entry = ""
            isAdding = false
        }
    }
}

extension WorkspaceModel {
    @discardableResult
    func addTag(_ input: String, to draft: TaskDraft) -> Bool {
        let tag = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        guard !draft.tags.contains(tag) else { return true }
        changeDraft(draft, keyPath: \.tags, to: draft.tags + [tag], actionName: "Add Tag")
        return true
    }
}

import SwiftUI

/// Render the draft until editing is explicitly requested; never convert rendered text back to source.
struct TaskMarkdownField: View {
    enum Kind {
        case title, notes

        var label: String {
            self == .title ? "Task title" : "Task notes"
        }

        var placeholder: String {
            self == .title ? "Title" : "Add notes…"
        }
    }

    @Binding var text: String
    let kind: Kind
    @Binding var isEditing: Bool
    @FocusState private var isSourceFocused: Bool

    var body: some View {
        if isEditing {
            source
                .focused($isSourceFocused)
                .accessibilityLabel("\(kind.label), Markdown")
                .background {
                    MarkdownEditingBoundary { endEditing() }
                }
                .task { isSourceFocused = true }
                .onChange(of: isSourceFocused) { wasFocused, focused in
                    if wasFocused, !focused {
                        isEditing = false
                    }
                }
                .onExitCommand { endEditing() }
        } else {
            rendered
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { isEditing = true }
                .focusable()
                .onKeyPress(.return) {
                    isEditing = true
                    return .handled
                }
                .accessibilityHint("Click or press Return to edit Markdown")
                .accessibilityAction(named: "Edit \(kind.label)") { isEditing = true }
        }
    }

    @ViewBuilder
    private var source: some View {
        if kind == .title {
            TextField("Title", text: $text, axis: .vertical)
                .labelsHidden()
                .lineLimit(1 ... 6)
                .font(.headline)
        } else {
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 160)
        }
    }

    @ViewBuilder
    private var rendered: some View {
        if text.isEmpty {
            Text(kind.placeholder)
                .foregroundStyle(.secondary)
                .font(kind == .title ? .headline : .body)
        } else if kind == .title {
            Text(TaskMarkdown.inline(text))
                .font(.headline)
        } else {
            TaskMarkdownPreview(source: text)
        }
    }

    private func endEditing() {
        isSourceFocused = false
        isEditing = false
    }
}

struct TaskNotesView: View {
    @Bindable var draft: TaskDraft
    @State private var isEditing = false

    var body: some View {
        Section("Notes") {
            TaskMarkdownField(text: $draft.notes, kind: .notes, isEditing: $isEditing)
        }
    }
}

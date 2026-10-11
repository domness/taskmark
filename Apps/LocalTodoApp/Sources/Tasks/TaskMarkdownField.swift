import SwiftUI

/// Render the draft until editing is explicitly requested; never convert rendered text back to source.
struct TaskMarkdownField: View {
    enum Kind {
        case title, notes

        var placeholder: String {
            self == .title ? "Title" : "Add notes…"
        }
    }

    @Binding var text: String
    let kind: Kind
    let subject: String
    @Binding var isEditing: Bool
    @FocusState private var isSourceFocused: Bool

    private var label: String {
        "\(subject) \(kind == .title ? "title" : "notes")"
    }

    var body: some View {
        if isEditing {
            source
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($isSourceFocused)
                .accessibilityLabel("\(label), Markdown")
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
                .accessibilityAction(named: "Edit \(label)") { isEditing = true }
        }
    }

    @ViewBuilder
    private var source: some View {
        if kind == .title {
            TextField("Title", text: $text, axis: .vertical)
                .labelsHidden()
                .lineLimit(1 ... 6)
                .themeFont(.headline)
                .background(Color(nsColor: .textBackgroundColor))
        } else {
            TextEditor(text: $text)
                .themeFont(.body)
                .foregroundStyle(.secondary)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                .background(Color.clear)
        }
    }

    @ViewBuilder
    private var rendered: some View {
        if text.isEmpty {
            Text(kind.placeholder)
                .foregroundStyle(.secondary)
                .themeFont(kind == .title ? .headline : .body)
        } else if kind == .title {
            Text(TaskMarkdown.inline(text))
                .themeFont(.headline)
        } else {
            let previewSource = TaskMarkdown.notesPreviewSource(text)
            if previewSource.allSatisfy(\.isWhitespace) {
                Text(kind.placeholder)
                    .foregroundStyle(.secondary)
                    .themeFont(.body)
            } else {
                TaskMarkdownPreview(source: previewSource)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func endEditing() {
        isSourceFocused = false
        isEditing = false
    }
}

struct TaskNotesView: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft
    @State private var isEditing: Bool

    init(model: WorkspaceModel, draft: TaskDraft, startsEditing: Bool = false) {
        self.model = model
        self.draft = draft
        _isEditing = State(initialValue: startsEditing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TaskMarkdownField(text: $draft.notes, kind: .notes, subject: "Task", isEditing: $isEditing)
            if !isEditing {
                TaskChecklistView(model: model, draft: draft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

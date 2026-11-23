import LocalTodoDomain
import SwiftUI

struct TaskMarkdownPreview: View {
    let source: String
    var checklist: MarkdownChecklist?
    var imageContext: TaskMarkdownImageContext?
    var setChecked: (MarkdownChecklist.Item, Bool) -> Void = { _, _ in }
    var deleteItem: (MarkdownChecklist.Item) -> Void = { _ in }
    let edit: () -> Void
    @Environment(\.themeTypography) private var typography

    var body: some View {
        let blocks = TaskMarkdown.blocks(source, checklist: checklist)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(TaskMarkdown.elements(in: blocks)) { element in
                switch element {
                case let .block(block):
                    blockView(block)
                case let .table(table):
                    TaskMarkdownTable(table: table, imageContext: imageContext)
                }
            }
            if blocks.isEmpty {
                Text("Add notes…")
                    .themeFont(.body)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: edit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("Edit Notes", action: edit)
        }
    }

    @ViewBuilder
    private func blockView(_ block: TaskMarkdown.Block) -> some View {
        if block.isThematicBreak {
            Divider()
                .contentShape(Rectangle())
                .onTapGesture(perform: edit)
        } else if let item = block.checklistItem {
            checklistRow(block, item: item)
        } else if block.text.runs.contains(where: { $0.link != nil || $0.imageURL != nil }) {
            textRow(block)
        } else {
            textRow(block)
                .contentShape(Rectangle())
                .onTapGesture(perform: edit)
        }
    }

    private func textRow(_ block: TaskMarkdown.Block) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let marker = block.listMarker {
                Text(marker)
            }
            if block.isQuote {
                Image(systemName: "quote.opening")
                    .accessibilityHidden(true)
            }
            TaskMarkdownText(text: block.text, imageContext: imageContext)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(block.headingLevel == nil ? [] : .isHeader)
        }
        .font(font(for: block))
        .padding(.leading, indentation(for: block) + (block.isInList && !block.showsMarker ? 16 : 0))
    }

    private func checklistRow(_ block: TaskMarkdown.Block, item: MarkdownChecklist.Item) -> some View {
        let label = block.text.characters.isEmpty ? AttributedString("Untitled step") : block.text
        let checked = Binding(get: { item.isChecked }, set: { setChecked(item, $0) })
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if label.runs.contains(where: { $0.link != nil || $0.imageURL != nil }) {
                Toggle(String(label.characters), isOn: checked).labelsHidden()
                TaskMarkdownText(text: label, imageContext: imageContext)
            } else {
                Toggle(isOn: checked) {
                    Text(label)
                }
            }
        }
        .toggleStyle(.checkbox)
        .themeFont(.body)
        .padding(.leading, indentation(for: block))
        .contextMenu {
            Button("Edit Notes", action: edit)
            Button("Delete Checklist Item", role: .destructive) { deleteItem(item) }
        }
    }

    private func indentation(for block: TaskMarkdown.Block) -> CGFloat {
        CGFloat(max(0, block.listDepth - 1) + max(0, block.quoteDepth - 1)) * 16
    }

    private func font(for block: TaskMarkdown.Block) -> Font {
        if block.isCode {
            return typography.font(.body, design: .monospaced)
        }
        switch block.headingLevel {
        case 1: return typography.font(.title2, weight: .bold)
        case 2: return typography.font(.title3, weight: .bold)
        case .some: return typography.font(.headline)
        case nil: return typography.font(.body)
        }
    }
}

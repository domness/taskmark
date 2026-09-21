import SwiftUI

struct TaskMarkdownPreview: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(TaskMarkdown.blocks(source)) { block in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let marker = block.listMarker {
                        Text(marker).foregroundStyle(.secondary)
                    }
                    if block.isQuote {
                        Image(systemName: "quote.opening").foregroundStyle(.secondary)
                    }
                    Text(block.text)
                        .font(font(for: block))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(max(0, block.listDepth - 1)) * 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func font(for block: TaskMarkdown.Block) -> Font {
        if block.isCode {
            return .body.monospaced()
        }
        switch block.headingLevel {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        case .some: return .headline
        case nil: return .body
        }
    }
}

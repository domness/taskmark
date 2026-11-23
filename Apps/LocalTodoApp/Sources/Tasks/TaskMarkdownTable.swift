import Foundation
import SwiftUI

extension TaskMarkdown {
    enum Element: Identifiable {
        case block(Block)
        case table(Table)

        var id: Int {
            switch self {
            case let .block(block): block.id
            case let .table(table): table.id
            }
        }
    }

    struct Table {
        let id: Int
        let sourceID: Int
        let columns: [PresentationIntent.TableColumn]
        var rows: [TableRow] = []
    }

    struct TableRow: Identifiable {
        let id: Int
        let isHeader: Bool
        var cells: [Int: AttributedString] = [:]
    }

    static func elements(in blocks: [Block]) -> [Element] {
        var result: [Element] = []
        var table: Table?
        for block in blocks {
            guard let cell = TableCell(block) else {
                if let table {
                    result.append(.table(table))
                }
                table = nil
                result.append(.block(block))
                continue
            }
            if table?.sourceID != cell.tableID {
                if let table {
                    result.append(.table(table))
                }
                table = Table(id: block.id, sourceID: cell.tableID, columns: cell.columns)
            }
            if table?.rows.last?.id != cell.rowID {
                table?.rows.append(TableRow(id: cell.rowID, isHeader: cell.isHeader))
            }
            if let last = table?.rows.indices.last {
                table?.rows[last].cells[cell.column] = block.text
            }
        }
        if let table {
            result.append(.table(table))
        }
        return result
    }
}

private struct TableCell {
    let tableID: Int
    let rowID: Int
    let column: Int
    let isHeader: Bool
    let columns: [PresentationIntent.TableColumn]

    init?(_ block: TaskMarkdown.Block) {
        var table: (Int, [PresentationIntent.TableColumn])?
        var row: PresentationIntent.IntentType?
        var columnIndex: Int?
        for component in block.components {
            switch component.kind {
            case let .table(columns): table = (component.identity, columns)
            case let .tableCell(index): columnIndex = index
            case .tableHeaderRow, .tableRow: row = component
            default: break
            }
        }
        guard let (tableID, columns) = table, let columnIndex, let row
        else { return nil }
        self.tableID = tableID
        rowID = row.identity
        column = columnIndex
        isHeader = row.kind == .tableHeaderRow
        self.columns = columns
    }
}

struct TaskMarkdownTable: View {
    let table: TaskMarkdown.Table
    let imageContext: TaskMarkdownImageContext?

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(table.rows) { row in
                    GridRow {
                        ForEach(table.columns.indices, id: \.self) { column in
                            TaskMarkdownText(text: row.cells[column] ?? "", imageContext: imageContext)
                                .gridColumnAlignment(alignment(table.columns[column].alignment))
                                .fontWeight(row.isHeader ? .semibold : .regular)
                                .accessibilityAddTraits(row.isHeader ? .isHeader : [])
                        }
                    }
                    if row.isHeader {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .themeFont(.body)
    }

    private func alignment(_ alignment: PresentationIntent.TableColumn.Alignment) -> HorizontalAlignment {
        switch alignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        @unknown default: .leading
        }
    }
}

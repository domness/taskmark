import Foundation

/// A conservative, line-based checklist projection. Only checkbox marker bytes are mutated.
public struct MarkdownChecklist: Sendable {
    public struct Item: Equatable, Identifiable, Sendable {
        public let id: Int
        public let title: String
        public let isChecked: Bool
    }

    public let body: String
    public let items: [Item]

    public init(_ body: String) {
        self.body = body
        var items: [Item] = []
        var offset = 0
        var fence: (marker: UInt8, count: Int)?
        var inComment = false
        for rawLine in body.utf8.split(separator: 10, omittingEmptySubsequences: false) {
            defer { offset += rawLine.count + 1 }
            let line = Array(rawLine.last == 13 ? rawLine.dropLast() : rawLine[...])
            let text = Self.text(line)
            if fence == nil, inComment || text.contains("<!--") {
                inComment = !text.contains("-->")
                continue
            }
            let indent = line.prefix(while: { $0 == 32 }).count
            guard indent <= 3 else { continue }
            let content = Array(line.dropFirst(indent))
            if let current = fence {
                let count = content.prefix(while: { $0 == current.marker }).count
                if count >= current.count, content.dropFirst(count).allSatisfy({ $0 == 32 || $0 == 9 }) {
                    fence = nil
                }
                continue
            }
            if let marker = content.first, marker == 96 || marker == 126 {
                let count = content.prefix(while: { $0 == marker }).count
                if count >= 3 {
                    fence = (marker, count)
                    continue
                }
            }
            if let marker = Self.checkboxOffset(content) {
                items.append(Item(
                    id: offset + indent + marker,
                    title: Self.text(Array(content.dropFirst(marker + 2)))
                        .trimmingCharacters(in: .whitespaces),
                    isChecked: content[marker] != 32
                ))
            }
        }
        self.items = items
    }

    public func settingChecked(_ checked: Bool, item: Item) throws -> String {
        guard items.contains(item) else { throw DomainValidationError.invalidChecklistItem }
        var bytes = Array(body.utf8)
        bytes[item.id] = checked ? 120 : 32
        return Self.text(bytes)
    }

    public func resetting() -> String {
        var bytes = Array(body.utf8)
        for item in items where item.isChecked {
            bytes[item.id] = 32
        }
        return Self.text(bytes)
    }

    private static func text(_ bytes: [UInt8]) -> String {
        // Slicing a String at ASCII delimiters and replacing ASCII markers preserves valid UTF-8.
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: bytes, as: UTF8.self)
    }

    private static func checkboxOffset(_ line: [UInt8]) -> Int? {
        guard let first = line.first else { return nil }
        var index = 1
        if ![UInt8(45), 42, 43].contains(first) {
            index = line.prefix(while: { (48 ... 57).contains($0) }).count
            guard (1 ... 9).contains(index), line.count > index, [UInt8(46), 41].contains(line[index]) else {
                return nil
            }
            index += 1
        }
        guard line.count > index, line[index] == 32 || line[index] == 9 else { return nil }
        while index < line.count, line[index] == 32 || line[index] == 9 {
            index += 1
        }
        guard line.count >= index + 3, line[index] == 91, line[index + 2] == 93,
              [UInt8(32), 120, 88].contains(line[index + 1]),
              line.count == index + 3 || line[index + 3] == 32 || line[index + 3] == 9
        else { return nil }
        return index + 1
    }
}

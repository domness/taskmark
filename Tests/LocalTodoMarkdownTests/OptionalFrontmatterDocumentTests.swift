import LocalTodoDomain
@testable import LocalTodoMarkdown
import Testing

private let optionalScalarFields = [
    ("task", "priority"), ("task", "scheduled"), ("task", "deadline"),
    ("task", "project"), ("task", "area"), ("task", "completed_at"),
    ("project", "area"), ("project", "completed_at"),
]

@Test(arguments: optionalScalarFields, ["[]", "[value]", "{}", "{value: nested}"])
func optionalFrontmatterRejectsCollections(field: (String, String), value: String) throws {
    let document = try optionalFieldDocument(type: field.0, fields: "\(field.1): \(value)")

    #expect(throws: EntityDocumentError.invalidField(field.1)) {
        try EntityDocumentCodec.decode(document, at: VaultPath("Entity.md"))
    }
}

@Test(arguments: optionalScalarFields + [("task", "recurrence")], ["null", "~", ""])
func optionalFrontmatterAcceptsAbsentAndNull(field: (String, String), value: String) throws {
    let absent = try optionalFieldDocument(type: field.0, fields: "")
    let explicitNull = try optionalFieldDocument(type: field.0, fields: "\(field.1): \(value)")
    let path = try VaultPath("Entity.md")
    let absentEntity = try EntityDocumentCodec.decode(absent, at: path)
    let nullEntity = try EntityDocumentCodec.decode(explicitNull, at: path)

    #expect(try EntityDocumentCodec.encode(absentEntity).rendered()
        == EntityDocumentCodec.encode(nullEntity).rendered())
}

@Test(arguments: [
    "[]", "[fixed]", "fixed", "{}",
    "{mode: []}", "{mode: {value: fixed}}", "{mode: null}",
    "{mode: fixed, rule: []}", "{mode: fixed, rule: {value: FREQ=DAILY}}",
    "{mode: fixed, rule: null}", "{mode: fixed}",
    "{mode: after-completion, interval: []}",
    "{mode: after-completion, interval: {value: P3D}}",
    "{mode: after-completion, interval: null}", "{mode: after-completion}",
])
func optionalFrontmatterRejectsMalformedRecurrence(value: String) throws {
    let document = try optionalFieldDocument(type: "task", fields: "recurrence: \(value)")

    #expect(throws: EntityDocumentError.invalidField("recurrence")) {
        try EntityDocumentCodec.decode(document, at: VaultPath("Entity.md"))
    }
}

@Test(arguments: ["task", "project", "area"])
func optionalFrontmatterPreservesUnknownValuesOnTitleEdit(type: String) throws {
    let original = try optionalFieldDocument(type: type, fields: """
    plugin_scalar: custom
    plugin_null: null
    plugin_sequence: [one, {nested: [two, null]}]
    plugin_mapping: {enabled: true, values: [1, 2]}
    """)
    var edited = original
    edited.set(.string("Updated title"), for: .title)
    let entity = try EntityDocumentCodec.decode(edited, at: VaultPath("Entity.md"))
    let reparsed = try MarkdownDocument.parse(
        EntityDocumentCodec.encode(entity, preserving: original).rendered()
    )

    #expect(reparsed.string(forKey: "title") == "Updated title")
    #expect(reparsed.body == original.body)
    for key in ["plugin_scalar", "plugin_null", "plugin_sequence", "plugin_mapping"] {
        #expect(reparsed.node(forKey: key) == original.node(forKey: key))
    }
}

private func optionalFieldDocument(type: String, fields: String) throws -> MarkdownDocument {
    try MarkdownDocument.parse("""
    ---
    type: \(type)
    title: Original title
    status: \(type == "task" ? "next" : "active")
    created_at: 2026-07-27T09:00:00Z
    updated_at: 2026-07-27T09:00:00Z
    \(fields)
    ---

    Notes with **formatting**.
    - [ ] Keep this checklist

    """)
}

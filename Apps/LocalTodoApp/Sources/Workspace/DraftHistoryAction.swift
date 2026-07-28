final class DraftHistoryAction<Value: Equatable>: @unchecked Sendable {
    let draft: TaskDraft
    let keyPath: ReferenceWritableKeyPath<TaskDraft, Value>
    let value: Value
    let actionName: String

    init(
        draft: TaskDraft,
        keyPath: ReferenceWritableKeyPath<TaskDraft, Value>,
        value: Value,
        actionName: String
    ) {
        self.draft = draft
        self.keyPath = keyPath
        self.value = value
        self.actionName = actionName
    }
}

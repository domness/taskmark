import LocalTodoMarkdown
import Observation

@MainActor
@Observable
final class FilterWorkspaceState {
    var record: SavedFilterRecord?
    var editor = TaskFilterEditor()
    var name = ""
    var editingName: String?
    var baseRevision: FileRevision?
    var isSaving = false
    var loadError: String?
    var saveError: String?
    var hasConflict = false
    @ObservationIgnored var readGeneration: UInt64 = 0

    func reset() {
        record = nil
        editor = TaskFilterEditor()
        name = ""
        editingName = nil
        baseRevision = nil
        isSaving = false
        loadError = nil
        saveError = nil
        hasConflict = false
        readGeneration += 1
    }
}

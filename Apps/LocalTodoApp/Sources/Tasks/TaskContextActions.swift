import LocalTodoDomain
import SwiftUI

struct TaskContextActions: View {
    let model: WorkspaceModel
    let path: VaultPath

    var body: some View {
        Button("Duplicate Task") { Task { await model.duplicateTask(at: path) } }
        Menu("Copy") {
            Button("Copy Title") { Task { await model.copyTask(at: path, format: .title) } }
            Button("Copy Markdown") { Task { await model.copyTask(at: path, format: .markdown) } }
            Button("Copy Vault-Relative Path") { Task { await model.copyTask(at: path, format: .path) } }
        }
        Button("Delete Task", role: .destructive) { Task { await model.deleteTask(at: path) } }
            .help("Delete this task. Use Edit → Undo to restore it during this vault session.")
    }
}

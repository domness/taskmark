import LocalTodoDomain
import SwiftUI

struct CommandPaletteView: View {
    let model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Type a command", text: $query)
                    .textFieldStyle(.plain)
                    .focused($focused)
            }
            .padding(14)
            Divider()
            List(filteredCommands) { command in
                Button {
                    command.action()
                    dismiss()
                } label: {
                    Label(command.title, systemImage: command.image)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .frame(width: 520, height: 420)
        .onAppear { focused = true }
    }

    private var filteredCommands: [PaletteCommand] {
        let commands = baseCommands + dynamicCommands + taskCommands
        guard !query.isEmpty else { return commands }
        return commands.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var baseCommands: [PaletteCommand] {
        [
            command("New Task", "plus.circle") { model.beginQuickCapture() },
            command("New Project", "square.stack") { model.newEntityKind = .project },
            command("New Area", "circle.grid.2x2") { model.newEntityKind = .area },
            command("Go to Today", "sun.max") { model.route = .today },
            command("Go to Inbox", "tray") { model.route = .inbox },
            command("Go to Next", "arrow.right.circle") { model.route = .next },
            command("Go to Upcoming", "calendar") { model.route = .upcoming },
            command("Go to Waiting", "hourglass") { model.route = .waiting },
            command("Go to Someday", "archivebox") { model.route = .someday },
            command("Filter Tasks", "line.3.horizontal.decrease.circle") { model.beginFilterEditing() },
            command("Search Tasks", "magnifyingglass") { model.route = .search },
            command("Toggle Inspector", "sidebar.trailing") { model.isInspectorPresented.toggle() },
            command("Switch Vault", "folder") { Task { await model.chooseVault() } },
        ]
    }

    private var dynamicCommands: [PaletteCommand] {
        guard let snapshot = model.snapshot else { return [] }
        let projects = snapshot.projects.values.map(\.value).map { project in
            command("Go to \(project.title)", "square.stack") { model.route = .project(project.path) }
        }
        let areas = snapshot.areas.values.map(\.value).map { area in
            command("Go to \(area.title)", "circle.grid.2x2") { model.route = .area(area.path) }
        }
        let filters = (model.filterState.record?.filters ?? []).map { filter in
            command("Filter: \(filter.name)", "line.3.horizontal.decrease.circle") {
                model.route = .savedFilter(filter.name)
            }
        }
        return (projects + areas + filters).sorted { $0.title < $1.title }
    }

    private var taskCommands: [PaletteCommand] {
        guard model.selectedTaskPath != nil else { return [] }
        let completion = command(
            model.selectedTaskIsComplete ? "Reopen Selected Task" : "Complete Selected Task",
            "checkmark.circle"
        ) { Task { await model.completeSelectedTask() } }
        var commands = [completion]
        if model.canRescheduleSelectedTask {
            commands.append(command("Reschedule Selected Task", "calendar") { model.beginRescheduling() })
        }
        return commands
    }

    private func command(_ title: String, _ image: String, action: @escaping @MainActor () -> Void) -> PaletteCommand {
        PaletteCommand(title: title, image: image, action: action)
    }
}

private struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let image: String
    let action: @MainActor () -> Void
}

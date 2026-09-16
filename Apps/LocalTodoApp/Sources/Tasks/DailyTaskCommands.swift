import SwiftUI

struct DailyTaskCommands: Commands {
    let model: WorkspaceModel

    var body: some Commands {
        CommandMenu("Task") {
            Button(model.selectedTaskIsComplete ? "Reopen Selected Task" : "Complete Selected Task") {
                Task { await model.completeSelectedTask() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model.selectedTaskPath == nil)
            Button("Edit Selected Task") {
                if let path = model.selectedTaskPath {
                    model.editTask(at: path)
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(model.selectedTaskPath == nil)
            Divider()
            Button("Reschedule Selected Task…") { model.beginRescheduling() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!model.canRescheduleSelectedTask)
            Button("Reschedule for Today") { model.rescheduleSelectedTask(daysFromToday: 0) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(!model.canRescheduleSelectedTask)
            Button("Reschedule for Tomorrow") { model.rescheduleSelectedTask(daysFromToday: 1) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(!model.canRescheduleSelectedTask)
        }
    }
}

import Foundation
import LocalTodoDomain
import SwiftUI

struct RescheduleSelection: Identifiable {
    let path: VaultPath
    let session: UUID
    let initialDate: String
    var id: VaultPath {
        path
    }
}

struct TaskRescheduleSheet: View {
    let model: WorkspaceModel
    let selection: RescheduleSelection
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var date: String

    init(model: WorkspaceModel, selection: RescheduleSelection) {
        self.model = model
        self.selection = selection
        _date = State(initialValue: selection.initialDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reschedule Task").themeFont(.headline)
            Text("Move the scheduled date, or the deadline if that is the only date. Paired dates move together.")
                .foregroundStyle(.secondary)
            TextField("New date (YYYY-MM-DD)", text: $date)
                .focused($isFocused)
            CalendarDateField(
                label: "Choose Date",
                systemImage: "calendar",
                text: date,
                calendar: model.planningCalendar
            ) {
                date = $0
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Reschedule") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled((try? CalendarDate(date)) == nil)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { isFocused = true }
    }

    private func apply() {
        guard let value = try? CalendarDate(date) else { return }
        if model.rescheduleTask(at: selection.path, to: value, session: selection.session) {
            dismiss()
        }
    }
}

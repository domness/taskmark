import SwiftUI

struct FilterDateRangesView: View {
    let model: WorkspaceModel
    @Binding var editor: TaskFilterEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            dateField("Scheduled from", text: $editor.scheduledFrom)
            dateField("Scheduled through", text: $editor.scheduledThrough)
            dateField("Deadline from", text: $editor.deadlineFrom)
            dateField("Deadline through", text: $editor.deadlineThrough)
        }
    }

    private func dateField(_ title: String, text: Binding<String>) -> some View {
        CalendarDateField(
            label: title,
            systemImage: "calendar",
            text: text.wrappedValue,
            calendar: model.planningCalendar
        ) {
            text.wrappedValue = $0
        }
    }
}

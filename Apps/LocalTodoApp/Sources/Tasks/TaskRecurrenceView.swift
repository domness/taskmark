import LocalTodoDomain
import SwiftUI

struct TaskRecurrenceView: View {
    let model: WorkspaceModel
    let draft: TaskDraft

    private var value: RecurrenceEditorValue {
        RecurrenceEditorValue(draft.recurrence)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InspectorPropertyRow("Repeat") {
                Picker("Repeat", selection: binding(\.mode)) {
                    ForEach(RecurrenceEditorValue.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            if value.mode != .none {
                Stepper("Every \(value.interval)", value: binding(\.interval), in: 1 ... 999)
                    .accessibilityLabel("Repeat interval")
                    .accessibilityValue(String(value.interval))
                if value.mode == .fixed {
                    InspectorPropertyRow("Frequency") {
                        Picker("Frequency", selection: binding(\.frequency)) {
                            ForEach(FixedRecurrenceRule.Frequency.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                    }
                    if value.frequency == .weekly {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Toggle(dayName(day), isOn: weekday(day))
                                .toggleStyle(.checkbox)
                        }
                        Text("With no weekdays selected, repeat on the task’s current weekday.")
                            .themeFont(.caption).foregroundStyle(.secondary)
                    }
                    Text("Missed occurrences are skipped when you complete the task.")
                        .themeFont(.caption).foregroundStyle(.secondary)
                } else {
                    InspectorPropertyRow("Unit") {
                        Picker("Unit", selection: binding(\.unit)) {
                            Text("Days").tag(RecurrenceInterval.Unit.day)
                            Text("Weeks").tag(RecurrenceInterval.Unit.week)
                            Text("Months").tag(RecurrenceInterval.Unit.month)
                            Text("Years").tag(RecurrenceInterval.Unit.year)
                        }
                    }
                    Text("The next date is calculated from the day you complete the task.")
                        .themeFont(.caption).foregroundStyle(.secondary)
                }
                Toggle("Reset checklist on repeat", isOn: Binding(
                    get: { draft.resetChecklistOnRepeat },
                    set: { model.changeDraft(
                        draft,
                        keyPath: \.resetChecklistOnRepeat,
                        to: $0,
                        actionName: "Change Checklist Reset"
                    ) }
                ))
                .toggleStyle(.checkbox)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<RecurrenceEditorValue, Value>) -> Binding<Value> {
        Binding(get: { value[keyPath: keyPath] }, set: { newValue in
            var updated = value
            updated[keyPath: keyPath] = newValue
            apply(updated)
        })
    }

    private func weekday(_ day: Weekday) -> Binding<Bool> {
        Binding(get: { value.weekdays.contains(day) }, set: { enabled in
            var updated = value
            updated.weekdays = Weekday.allCases.filter { $0 == day ? enabled : value.weekdays.contains($0) }
            apply(updated)
        })
    }

    private func apply(_ value: RecurrenceEditorValue) {
        do {
            try model.changeDraft(draft, keyPath: \.recurrence, to: value.recurrence(), actionName: "Change Repeat")
        } catch {
            model.errorMessage = "Choose a repeat interval between 1 and 999."
        }
    }

    private func dayName(_ day: Weekday) -> String {
        switch day {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
}

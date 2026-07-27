import LocalTodoDomain
import SwiftUI

struct CalendarDateField: View {
    let label: String
    @Binding var text: String
    let calendar: Calendar
    let onCalendarChange: (String) -> Void

    @State private var isCalendarPresented = false
    @State private var pickerDate = Date()

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("YYYY-MM-DD", text: $text)
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 112)
                    .accessibilityLabel(label)
                if isInvalid {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                        .help("Use YYYY-MM-DD")
                        .accessibilityLabel("Invalid date. Use YYYY-MM-DD.")
                }
                Button("Choose \(label)", systemImage: "calendar") {
                    prepareCalendar()
                }
                .labelStyle(.iconOnly)
                .popover(isPresented: $isCalendarPresented, arrowEdge: .trailing) {
                    calendarPopover
                }
            }
        }
    }

    private var calendarPopover: some View {
        VStack(alignment: .trailing, spacing: 10) {
            DatePicker(
                label,
                selection: Binding(
                    get: { pickerDate },
                    set: { date in
                        pickerDate = date
                        if let value = try? CalendarDate(date: date, calendar: calendar) {
                            onCalendarChange(value.description)
                        }
                    }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            HStack {
                Button("Clear") {
                    onCalendarChange("")
                    isCalendarPresented = false
                }
                Spacer()
                Button("Done") { isCalendarPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .padding(12)
    }

    private var isInvalid: Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && (try? CalendarDate(value)) == nil
    }

    private func prepareCalendar() {
        let value = try? CalendarDate(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if let value, let date = try? value.date(in: calendar) {
            pickerDate = date
        } else {
            pickerDate = Date()
        }
        isCalendarPresented = true
    }
}

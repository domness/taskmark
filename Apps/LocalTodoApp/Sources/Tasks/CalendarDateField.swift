import Foundation
import LocalTodoDomain
import SwiftUI

struct CalendarDateField: View {
    let label: String
    let systemImage: String
    let text: String
    let calendar: Calendar
    let now: () -> Date
    let onCalendarChange: (String) -> Void

    @State private var isCalendarPresented = false
    @State private var pickerDate: Date
    @State private var exactDateText = ""

    init(
        label: String,
        systemImage: String,
        text: String,
        calendar: Calendar,
        now: @escaping () -> Date = Date.init,
        onCalendarChange: @escaping (String) -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.text = text
        self.calendar = calendar
        self.now = now
        self.onCalendarChange = onCalendarChange
        _pickerDate = State(initialValue: now())
    }

    var body: some View {
        Button {
            prepareCalendar()
        } label: {
            Label(buttonTitle, systemImage: systemImage)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityTitle)
        .popover(isPresented: $isCalendarPresented, arrowEdge: .top) {
            calendarPopover
        }
    }

    private var calendarPopover: some View {
        VStack(spacing: 0) {
            exactDateEntry

            Divider()

            VStack(spacing: 2) {
                ForEach(CalendarDateSuggestion.options(now: now(), calendar: calendar)) { suggestion in
                    Button {
                        select(suggestion.date)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: suggestion.systemImage)
                                .frame(width: 16)
                                .foregroundStyle(.secondary)
                            Text(suggestion.title)
                            Spacer(minLength: 24)
                            if let date = suggestion.date {
                                Text(shortDate(date))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            if isSelected(suggestion) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(suggestionAccessibilityTitle(suggestion))
                    .accessibilityValue(isSelected(suggestion) ? "Selected" : "")
                }
            }
            .padding(6)

            Divider()

            DatePicker(
                label,
                selection: Binding(
                    get: { pickerDate },
                    set: { date in
                        pickerDate = date
                        guard let value = try? CalendarDate(date: date, calendar: calendar) else { return }
                        select(value)
                    }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .padding(10)
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .frame(width: 280)
    }

    private var buttonTitle: String {
        guard let value = selectedDate else { return label }
        return "\(label): \(shortDate(value))"
    }

    private var accessibilityTitle: String {
        guard let value = selectedDate else { return "\(label), no date" }
        return "\(label), \(longDate(value))"
    }

    private var selectedDate: CalendarDate? {
        try? CalendarDate(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var exactDateEntry: some View {
        HStack(spacing: 8) {
            TextField("YYYY-MM-DD", text: $exactDateText)
                .textFieldStyle(.plain)
                .font(.body.monospacedDigit())
                .onSubmit { applyExactDate() }
                .accessibilityLabel("Exact \(label.lowercased()) date")
            if !exactDateText.isEmpty, exactDate == nil {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                    .help("Use YYYY-MM-DD")
                    .accessibilityLabel("Invalid date. Use YYYY-MM-DD.")
            }
            Button("Set Date", systemImage: "checkmark") { applyExactDate() }
                .labelStyle(.iconOnly)
                .disabled(exactDate == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var exactDate: CalendarDate? {
        try? CalendarDate(exactDateText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func prepareCalendar() {
        let currentDate = now()
        exactDateText = text
        if let value = selectedDate, let date = try? value.date(in: calendar) {
            pickerDate = date
        } else {
            pickerDate = currentDate
        }
        isCalendarPresented = true
    }

    private func select(_ value: CalendarDate?) {
        exactDateText = value?.description ?? ""
        onCalendarChange(value?.description ?? "")
        isCalendarPresented = false
    }

    private func applyExactDate() {
        guard let exactDate else { return }
        select(exactDate)
    }

    private func isSelected(_ suggestion: CalendarDateSuggestion) -> Bool {
        suggestion.date == selectedDate
    }

    private func shortDate(_ value: CalendarDate) -> String {
        formatted(value, template: value.year == currentYear ? "MMMd" : "yMMMd")
    }

    private func longDate(_ value: CalendarDate) -> String {
        formatted(value, template: "yMMMMd")
    }

    private func formatted(_ value: CalendarDate, template: String) -> String {
        guard let date = try? value.date(in: calendar) else { return value.description }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private var currentYear: Int {
        calendar.component(.year, from: now())
    }

    private func suggestionAccessibilityTitle(_ suggestion: CalendarDateSuggestion) -> String {
        guard let date = suggestion.date else { return suggestion.title }
        return "\(suggestion.title), \(longDate(date))"
    }
}

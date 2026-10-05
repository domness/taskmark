import LocalTodoDomain
import SwiftUI

struct TaskCompletionIcon: View {
    let status: TaskStatus
    let showsCompletionFeedback: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Image(systemName: statusImage)
                .opacity(showsCompletionFeedback ? 0 : 1)
                .scaleEffect(showsCompletionFeedback && !reduceMotion ? 0.7 : 1)
            Image(systemName: "checkmark.circle.fill")
                .opacity(showsCompletionFeedback ? 1 : 0)
                .scaleEffect(showsCompletionFeedback && !reduceMotion ? 1.12 : 1)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: showsCompletionFeedback)
        .accessibilityHidden(true)
    }

    private var statusImage: String {
        switch status {
        case .done: "checkmark.circle.fill"
        case .canceled: "xmark.circle.fill"
        default: "circle"
        }
    }
}

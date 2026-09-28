import LocalTodoPresentation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

typealias AppTheme = TaskmarkTheme

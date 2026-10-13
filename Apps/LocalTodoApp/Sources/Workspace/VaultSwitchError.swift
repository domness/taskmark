import Foundation

enum VaultSwitchError: LocalizedError {
    case unsavedTaskChanges
    case activeQuickCapture
    case activeMutation

    var errorDescription: String? {
        switch self {
        case .unsavedTaskChanges: "Wait for task changes to save or fix invalid fields before switching vaults."
        case .activeQuickCapture: "Finish or cancel quick capture before switching vaults."
        case .activeMutation: "Wait for the current change to finish before switching vaults."
        }
    }
}

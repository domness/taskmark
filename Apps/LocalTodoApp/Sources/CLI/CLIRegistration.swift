import Foundation
import Observation

@MainActor @Observable
final class CLIRegistration {
    private(set) var isEnabled = false
    private(set) var isWorking = false
    var errorMessage: String?

    private let inspect: () -> Bool
    private let apply: (Bool) async throws -> Void

    init(
        inspect: @escaping () -> Bool = { CLIInstaller.isRegistered(source: CLIInstaller.bundledExecutable()) },
        apply: @escaping (Bool) async throws -> Void = { enabled in
            let source = CLIInstaller.bundledExecutable()
            try await Task.detached { try CLIInstaller.setEnabled(enabled, source: source) }.value
        }
    ) {
        self.inspect = inspect
        self.apply = apply
        refresh()
    }

    func refresh() {
        guard !isWorking else { return }
        isEnabled = inspect()
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer {
            isWorking = false
            refresh()
        }
        do {
            try await apply(enabled)
            if inspect() != enabled {
                errorMessage = "CLI registration could not be verified. Try enabling it again."
            }
        } catch CLIInstallationError.authorizationCancelled {
            // The system authorization dialog already communicates cancellation; retain actual disk state.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import Combine
import Foundation
import Sparkle

/// One updater for the application; Sparkle owns machine-local preferences and scheduling.
@MainActor
final class AppUpdates: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?
    @Published private(set) var startupError: String?
    private let controller: SPUStandardUpdaterController
    private var didStart = false

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        controller.updater.publisher(for: \.lastUpdateCheckDate).assign(to: &$lastUpdateCheckDate)
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        guard Self.hasSigningKey(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) else {
            startupError = "Updates are unavailable in this development build. Install a signed release from GitHub."
            return
        }
        do {
            try controller.updater.start()
        } catch {
            startupError = "Updates could not start: \(error.localizedDescription)"
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    static func hasSigningKey(_ value: String?) -> Bool {
        guard let value, let data = Data(base64Encoded: value) else { return false }
        return data.count == 32
    }
}

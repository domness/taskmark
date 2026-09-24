import Foundation
@testable import LocalTodoApp
import Testing

@MainActor
struct AppUpdatesTests {
    @Test func signingConfigurationRejectsUnconfiguredBuilds() {
        #expect(!AppUpdates.hasSigningKey(nil))
        #expect(!AppUpdates.hasSigningKey(""))
        #expect(!AppUpdates.hasSigningKey("$(SPARKLE_PUBLIC_ED_KEY)"))
        #expect(!AppUpdates.hasSigningKey(Data(repeating: 1, count: 31).base64EncodedString()))
        #expect(AppUpdates.hasSigningKey(Data(repeating: 1, count: 32).base64EncodedString()))
    }

    @Test func updaterDoesNotStartOrCheckDuringConstruction() {
        let updates = AppUpdates()
        #expect(!updates.canCheckForUpdates)
        updates.checkForUpdates()
        #expect(!updates.canCheckForUpdates)
        #expect(updates.startupError == nil)
    }

    @Test func unconfiguredBuildExplainsUnavailableUpdates() {
        guard !AppUpdates.hasSigningKey(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) else {
            return
        }
        let updates = AppUpdates()
        updates.start()
        let message = updates.startupError
        #expect(message?.contains("development build") == true)
        #expect(!updates.canCheckForUpdates)
        updates.start()
        #expect(updates.startupError == message)
    }

    @Test func bundledUpdatePolicyUsesStableGitHubReleasesAndOptInChecking() {
        let bundle = Bundle.main
        #expect(bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
            == "https://github.com/domness/taskmark/releases/latest/download/appcast.xml")
        #expect(bundle.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool == false)
        #expect(bundle.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool == false)
        #expect(bundle.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates") as? Bool == false)
        #expect(bundle.object(forInfoDictionaryKey: "SUEnableSystemProfiling") as? Bool == false)
    }
}

import Foundation
@testable import LocalTodoApp
import Testing

@MainActor
struct CLIRegistrationTests {
    @Test func reflectsDiskStateAfterRegistrationAndRemoval() async {
        var registered = false
        let model = CLIRegistration(inspect: { registered }, apply: { registered = $0 })
        #expect(!model.isEnabled)
        await model.setEnabled(true)
        #expect(model.isEnabled)
        #expect(model.errorMessage == nil)
        await model.setEnabled(false)
        #expect(!model.isEnabled)
        #expect(!model.isWorking)
        registered = true
        model.refresh()
        #expect(model.isEnabled)
    }

    @Test func cancelledAuthorizationKeepsActualState() async {
        let model = CLIRegistration(inspect: { false }, apply: { _ in
            throw CLIInstallationError.authorizationCancelled
        })
        await model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(!model.isWorking)
        #expect(model.errorMessage == nil)
    }

    @Test func failedRemovalRetainsEnabledStateAndShowsError() async {
        let model = CLIRegistration(inspect: { true }, apply: { _ in
            throw CLIInstallationError.registrationFailed("Permission denied")
        })
        await model.setEnabled(false)
        #expect(model.isEnabled)
        #expect(model.errorMessage == "Permission denied")
        #expect(!model.isWorking)
    }

    @Test func verifiesRegistrationInsteadOfAssumingSuccess() async {
        let model = CLIRegistration(inspect: { false }, apply: { _ in })
        await model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(model.errorMessage != nil)
    }
}

import Foundation
@testable import LocalTodoApp
import Testing

@MainActor
struct WorkspaceFixtureTests {
    @Test(arguments: [false, true])
    func retainedWorkspaceIsReleasedBeforeFixtureRemoval(throwsFromOperation: Bool) async throws {
        // SwiftUI/AppKit can retain a closed test host and its workspace past fixture teardown.
        var retainedModel: WorkspaceModel?
        var fixtureURL: URL?
        var originalSession: UUID?
        do {
            try await withWorkspace { model, root in
                retainedModel = model
                fixtureURL = root
                originalSession = model.vaultSession
                if throwsFromOperation {
                    throw FixtureFailure.expected
                }
            }
            #expect(!throwsFromOperation)
        } catch FixtureFailure.expected {
            #expect(throwsFromOperation)
        }

        let model = try #require(retainedModel)
        let root = try #require(fixtureURL)
        #expect(!FileManager.default.fileExists(atPath: root.path))
        #expect(model.rootURL == nil)
        #expect(model.store == nil)
        #expect(model.snapshot == nil)
        #expect(model.vaultSession != originalSession)
        // A late scene activation must not read the deleted vault or present an alert.
        await model.refresh()
        #expect(model.errorMessage == nil)
    }

    private enum FixtureFailure: Error {
        case expected
    }
}

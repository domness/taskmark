import XCTest

@MainActor
final class TaskmarkIOSUITests: XCTestCase {
    func testOnboardingOffersOpenAndCreate() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["open-vault"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["create-vault"].exists)
    }

    func testDailyNavigationAndCaptureOpenAgainstRealVault() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today fixture"].exists)
        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["Inbox fixture"].waitForExistence(timeout: 2))
        app.buttons["add-task"].tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 2))
    }

    func testCapturePersistsThroughTheCanonicalVault() {
        let app = launchFixtureApp()
        app.buttons["add-task"].tap()
        let title = app.textFields["Task title"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        title.typeText("Captured on iPhone")
        app.buttons["Add"].tap()

        XCTAssertTrue(app.navigationBars["New Task"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Captured on iPhone"].waitForExistence(timeout: 5))
    }

    func testIncompleteVaultKeepsNavigationTitleVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-incomplete"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Vault data is incomplete"].exists)
        XCTAssertTrue(app.buttons["Retry"].exists)
    }

    func testTaskDetailExposesPlanningRecurrenceAndFileActions() {
        let app = launchFixtureApp()
        app.staticTexts["Today fixture"].tap()

        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Edit Markdown"].exists)
        XCTAssertTrue(app.buttons["Repeat"].exists || app.staticTexts["Repeat"].exists)
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Copy Markdown"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Copy Relative Path"].waitForExistence(timeout: 2))
    }

    func testBrowseReachesSettingsVaultStatusAndRecovery() {
        let app = launchFixtureApp()
        app.tabBars.buttons["Browse"].tap()

        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 2))
        app.buttons["Vault Status"].tap()
        XCTAssertTrue(app.navigationBars["Vault Status"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Unsaved Changes"].exists)
        XCTAssertTrue(app.buttons["Retry"].exists)
    }

    func testTabletAdaptiveWorkspaceShowsSidebarListAndDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let workspace = app.descendants(matching: .any)["tablet-workspace"]
        guard workspace.waitForExistence(timeout: 5) else {
            throw XCTSkip("The tablet workspace is available only in a regular horizontal size class.")
        }
        XCTAssertTrue(app.staticTexts["Today"].exists)
        if app.staticTexts["Search"].exists {
            app.staticTexts["Search"].tap()
            XCTAssertTrue(app.searchFields["Tasks and notes"].waitForExistence(timeout: 2))
            app.staticTexts["Today"].firstMatch.tap()
        } else {
            let sidebarButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch
            XCTAssertTrue(sidebarButton.waitForExistence(timeout: 2))
        }
        XCTAssertTrue(app.staticTexts["Today fixture"].waitForExistence(timeout: 2))

        app.staticTexts["Today fixture"].tap()
        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 2))
    }

    private func launchFixtureApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        return app
    }
}

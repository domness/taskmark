import XCTest

@MainActor
final class SampleVaultUITests: XCTestCase {
    func testSampleOnboardingOpensEditableVaultAndRestoresChanges() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["TASKMARK_UI_TEST_SESSION"] = UUID().uuidString
        app.launchArguments = ["--ui-testing-onboarding"]
        app.launch()
        let sample = app.buttons["sample-vault"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertTrue(sample.isHittable)
        attachScreenshot(app, name: "Welcome")
        sample.tap()
        let firstTask = app.staticTexts["1. Make yourself at home"]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 10))
        firstTask.tap()
        verifySampleEditing(app)
        attachScreenshot(app, name: "Sample instructions")
        // Return to the task list on either the compact or split layout.
        if app.tabBars.buttons["Today"].exists {
            app.navigationBars["Task"].buttons.firstMatch.tap()
        }
        app.buttons["add-task"].firstMatch.tap()
        let title = app.textFields["capture-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("My sample experiment")
        let submit = app.buttons["capture-submit"]
        XCTAssertTrue(submit.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["My sample experiment"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["My sample experiment"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "Restored sample")
    }

    func testWelcomeSupportsAccessibilityText() {
        let app = XCUIApplication()
        app.launchEnvironment["TASKMARK_UI_TEST_SESSION"] = UUID().uuidString
        app.launchArguments = [
            "--ui-testing-onboarding", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["sample-vault"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Welcome accessibility text")
        for _ in 0 ..< 4 where !app.buttons["open-vault"].isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["open-vault"].isHittable)
        XCTAssertTrue(app.buttons["create-vault"].exists)
        attachScreenshot(app, name: "Welcome accessibility actions")
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func verifySampleEditing(_ app: XCUIApplication) {
        // The inline action follows long notes and can be outside a lazy Form's
        // visible rows on iPad. The toolbar action is available at every size.
        let navigation = app.navigationBars["Task"]
        let edit = navigation.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertTrue(edit.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        edit.tap()
        let title = app.textFields.matching(NSPredicate(format: "value == %@", "1. Make yourself at home")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        navigation.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
    }
}

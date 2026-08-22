import XCTest

@MainActor
final class WorkshopVisualUITests: XCTestCase {
    func testSettingsSurface() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WORKSHOP_DEMO_MODE"] = "1"
        app.launch()

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5))
        moreTab.tap()

        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Annotation Color"].exists)
        XCTAssertTrue(app.staticTexts["Text Size"].exists)
        attachScreenshot(named: "Workshop Settings")
    }

    func testShareConfirmationSurface() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-share-confirmation"]
        app.launch()

        let confirmation = app.descendants(matching: .any)["share-confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        attachScreenshot(named: "Share Extension Confirmation")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

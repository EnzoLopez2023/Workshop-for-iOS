import XCTest

@MainActor
final class WorkshopVisualUITests: XCTestCase {
    func testAppStoreScreenshotStory() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["WORKSHOP_DEMO_MODE"] = "1"
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ws.appearance", "dark",
        ]
        app.launch()

        let activeProject = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Hand Tool Storage Cabinet"))
            .firstMatch
        XCTAssertTrue(activeProject.waitForExistence(timeout: 8))
        attachScreenshot(named: "01-dashboard")

        activeProject.tap()
        XCTAssertTrue(app.navigationBars["Hand Tool Storage Cabinet"].waitForExistence(timeout: 5))
        attachScreenshot(named: "02-project-detail")

        selectDestination("Shopping", in: app)
        XCTAssertTrue(app.staticTexts["Hand Tool Storage Cabinet"].waitForExistence(timeout: 5))
        attachScreenshot(named: "03-shopping-list")

        selectDestination("Tables", in: app)
        XCTAssertTrue(app.staticTexts["Quick Converter"].waitForExistence(timeout: 5))
        attachScreenshot(named: "04-conversion-tables")

        selectDestination("More", in: app)
        let insights = app.buttons["Insights"]
        XCTAssertTrue(insights.waitForExistence(timeout: 5))
        insights.tap()
        XCTAssertTrue(app.staticTexts["Spend Over Time"].waitForExistence(timeout: 5))
        attachScreenshot(named: "05-insights")
    }

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

    private func selectDestination(_ name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        if tab.exists {
            tab.tap()
            return
        }

        let sidebar = app.buttons[name]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        sidebar.tap()
        Thread.sleep(forTimeInterval: 0.5)
        if !app.buttons[name].isSelected {
            app.buttons[name].tap()
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

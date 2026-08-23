import XCTest

@MainActor
final class WorkshopVisualUITests: XCTestCase {
    func testSignInExplainsProviderScopedWorkspaces() {
        assertProviderScopedSignIn()
    }

    func testSignInDisclosureAtAccessibilityTextSize() {
        assertProviderScopedSignIn(dynamicType: "accessibility3")
    }

    private func assertProviderScopedSignIn(dynamicType: String? = nil) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-sign-in"]
        if let dynamicType {
            app.launchEnvironment["WORKSHOP_UI_TEST_DYNAMIC_TYPE"] = dynamicType
        }
        app.launch()

        XCTAssertTrue(app.buttons["Sign in with Microsoft"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        let disclosure = app.staticTexts["provider-scope-disclosure"]
        XCTAssertTrue(disclosure.exists)
        for _ in 0..<6 where !disclosure.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(disclosure.isHittable)
        XCTAssertEqual(
            disclosure.label,
            "Apple and Microsoft create separate Workshop workspaces. Use the same sign-in each time to return to your projects. Apple and Microsoft workspaces are not linked or merged automatically."
        )
        attachScreenshot(named: "Provider Sign-In Disclosure")
    }

    func testAppleAccountShowsProviderScopedDeletion() {
        assertProviderScopedAccount(
            provider: "apple",
            displayName: "Apple",
            otherProvider: "Microsoft",
            underlyingAccount: "Apple Account"
        )
    }

    func testMicrosoftAccountShowsProviderScopedDeletion() {
        assertProviderScopedAccount(
            provider: "microsoft",
            displayName: "Microsoft",
            otherProvider: "Apple",
            underlyingAccount: "Microsoft account"
        )
    }

    func testAppleAccountScopeAtAccessibilityTextSize() {
        assertProviderScopedAccount(
            provider: "apple",
            displayName: "Apple",
            otherProvider: "Microsoft",
            underlyingAccount: "Apple Account",
            dynamicType: "accessibility3"
        )
    }

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

    private func assertProviderScopedAccount(
        provider: String,
        displayName: String,
        otherProvider: String,
        underlyingAccount: String,
        dynamicType: String? = nil
    ) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WORKSHOP_UI_TEST_ACCOUNT_PROVIDER"] = provider
        app.launchEnvironment["WORKSHOP_START_TAB"] = "more"
        if let dynamicType {
            app.launchEnvironment["WORKSHOP_UI_TEST_DYNAMIC_TYPE"] = dynamicType
        }
        app.launch()

        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
        let providerRow = app.descendants(matching: .any)["account-provider"]
        scrollUntilExists(providerRow, in: app)
        XCTAssertTrue(providerRow.exists)
        XCTAssertEqual(providerRow.label, "Provider")
        XCTAssertEqual(providerRow.value as? String, displayName)

        let workspaceDisclosure = app.staticTexts["provider-workspace-disclosure"]
        XCTAssertTrue(workspaceDisclosure.exists)
        XCTAssertTrue(workspaceDisclosure.label.contains("\(displayName) sign-in"))
        XCTAssertTrue(workspaceDisclosure.label.contains("not linked or merged"))

        let footer = app.descendants(matching: .any)["provider-deletion-scope"]
        scrollUntilExists(footer, in: app)
        XCTAssertTrue(footer.exists)
        XCTAssertTrue(footer.label.contains("only this \(displayName)-backed"))
        XCTAssertTrue(footer.label.contains(underlyingAccount))
        XCTAssertTrue(footer.label.contains("\(otherProvider)-backed"))
        attachScreenshot(named: "\(displayName) Account Provider")

        let deleteButton = app.buttons["Delete Account"]
        scrollUntilHittable(deleteButton, in: app)
        XCTAssertTrue(deleteButton.isHittable)
        deleteButton.tap()
        let alert = app.alerts["Delete \(displayName) Workspace?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let messageElement = alert.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Deletes only this \(displayName)")
        ).firstMatch
        XCTAssertTrue(messageElement.exists)
        let message = messageElement.label
        XCTAssertTrue(message.contains("Deletes only this \(displayName)"))
        XCTAssertTrue(message.contains("\(otherProvider) Workshop workspace"))
        XCTAssertTrue(message.contains("starter projects"))
        XCTAssertTrue(message.contains("deleted content does not return"))
        attachScreenshot(named: "\(displayName) Deletion Confirmation")
        alert.buttons["Cancel"].tap()
    }

    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 where !element.exists {
            app.swipeUp()
        }
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 where !element.isHittable {
            app.swipeUp()
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

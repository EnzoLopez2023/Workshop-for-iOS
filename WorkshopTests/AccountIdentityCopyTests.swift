import XCTest
@testable import Workshop

final class AccountIdentityCopyTests: XCTestCase {
    func testSignInDisclosureExplainsSeparateUnlinkedWorkspaces() {
        XCTAssertEqual(
            WorkshopAccountCopy.signInDisclosure,
            "Apple and Microsoft create separate Workshop workspaces. Use the same sign-in each time to return to your projects. Apple and Microsoft workspaces are not linked or merged automatically."
        )
    }

    func testProviderLabelsAreExplicit() {
        XCTAssertEqual(WorkshopAccountProvider.apple.displayName, "Apple")
        XCTAssertEqual(WorkshopAccountProvider.microsoft.displayName, "Microsoft")
    }

    func testWorkspaceDisclosureNamesBothProviders() {
        for provider in WorkshopAccountProvider.allCases {
            let copy = WorkshopAccountCopy.workspaceDisclosure(for: provider)
            XCTAssertTrue(copy.contains(provider.displayName))
            XCTAssertTrue(copy.contains("Apple and Microsoft"))
            XCTAssertTrue(copy.contains("not linked or merged"))
        }
    }

    func testDeletionFooterScopesEachProviderAndProtectsTheOther() {
        for provider in WorkshopAccountProvider.allCases {
            let copy = WorkshopAccountCopy.deletionFooter(for: provider)
            XCTAssertTrue(copy.contains("only this \(provider.displayName)-backed"))
            XCTAssertTrue(copy.contains(provider.underlyingAccountName))
            XCTAssertTrue(copy.contains(provider.other.displayName))
            XCTAssertTrue(copy.contains("not affected"))
        }
    }

    func testDeletionConfirmationExplainsFreshRecreation() {
        for provider in WorkshopAccountProvider.allCases {
            let copy = WorkshopAccountCopy.deletionConfirmation(for: provider)
            XCTAssertTrue(copy.contains("Signing in with \(provider.displayName) again"))
            XCTAssertTrue(copy.contains("starter projects"))
            XCTAssertTrue(copy.contains("deleted content does not return"))
            XCTAssertTrue(copy.contains("This cannot be undone"))
        }
    }

    func testAppleAndMicrosoftIdentityNamespacesDoNotCollide() throws {
        let microsoftKey = try XCTUnwrap(
            EntraIdentity.userKey(
                tenantID: "399388F8-9DCD-4BE8-B6D5-AF07D1168285",
                objectID: "2B104079-BAD0-4F79-A2DB-3BF67E4194BE"
            )
        )
        let appleKey = "apple_6b2f6f5f1a6e3c50e58f51bd57bfc8b8f2397608b6c55c13914f8610b47c07d4"

        XCTAssertFalse(microsoftKey.hasPrefix("apple_"))
        XCTAssertNotEqual(microsoftKey, appleKey)
    }

    func testStarterContentMarkersRemainProviderScopedAndResetAfterDeletion() throws {
        let suiteName = "AccountIdentityCopyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appleKey = "apple_6b2f6f5f1a6e3c50e58f51bd57bfc8b8f2397608b6c55c13914f8610b47c07d4"
        let microsoftKey = try XCTUnwrap(
            EntraIdentity.userKey(
                tenantID: "399388F8-9DCD-4BE8-B6D5-AF07D1168285",
                objectID: "2B104079-BAD0-4F79-A2DB-3BF67E4194BE"
            )
        )

        StarterSeeder.markRun(userKey: appleKey, defaults: defaults)
        XCTAssertTrue(StarterSeeder.hasRun(userKey: appleKey, defaults: defaults))
        XCTAssertFalse(StarterSeeder.hasRun(userKey: microsoftKey, defaults: defaults))

        StarterSeeder.clearRun(userKey: appleKey, defaults: defaults)
        XCTAssertFalse(StarterSeeder.hasRun(userKey: appleKey, defaults: defaults))
    }
}

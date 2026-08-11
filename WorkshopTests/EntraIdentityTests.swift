import XCTest
@testable import Workshop

final class EntraIdentityTests: XCTestCase {
    private let homeTenantID = "52188f12-db6b-46c6-88ff-08c802f0ed3b"
    private let personalTenantID = "9188040d-6c67-4c5b-b112-36a304b66dad"
    private let objectID = "2B104079-BAD0-4F79-A2DB-3BF67E4194BE"

    func testLegacyHomeTenantKeepsBareObjectID() {
        XCTAssertEqual(
            EntraIdentity.userKey(tenantID: homeTenantID, objectID: objectID),
            "2b104079-bad0-4f79-a2db-3bf67e4194be"
        )
    }

    func testExternalTenantIsNamespaced() {
        XCTAssertEqual(
            EntraIdentity.userKey(
                tenantID: "399388F8-9DCD-4BE8-B6D5-AF07D1168285",
                objectID: objectID
            ),
            "399388f8-9dcd-4be8-b6d5-af07d1168285_2b104079-bad0-4f79-a2db-3bf67e4194be"
        )
    }

    func testPersonalMicrosoftAccountIsNamespaced() {
        XCTAssertEqual(
            EntraIdentity.userKey(tenantID: personalTenantID, objectID: objectID),
            "9188040d-6c67-4c5b-b112-36a304b66dad_2b104079-bad0-4f79-a2db-3bf67e4194be"
        )
    }

    func testMalformedOrMissingClaimsAreRejected() {
        XCTAssertNil(EntraIdentity.userKey(tenantID: nil, objectID: objectID))
        XCTAssertNil(EntraIdentity.userKey(tenantID: homeTenantID, objectID: nil))
        XCTAssertNil(EntraIdentity.userKey(tenantID: "common", objectID: objectID))
        XCTAssertNil(EntraIdentity.userKey(tenantID: homeTenantID, objectID: "not-an-oid"))
    }
}

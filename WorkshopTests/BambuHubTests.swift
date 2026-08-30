import XCTest
import NintekKit
@testable import Workshop

final class BambuHubTests: XCTestCase {
    func testDemoCatalogReturnsAnEmptyBambuList() throws {
        let data = try XCTUnwrap(
            DemoWorkshopData.responseData(for: "/api/bambu-projects")
        )

        let projects = try JSONDecoder().decode([BambuProject].self, from: data)

        XCTAssertTrue(projects.isEmpty)
    }

    func testSafeFilenameRemovesPathTraversalAndUnsafeCharacters() {
        XCTAssertEqual(
            BambuUI.safeFilename(
                "../../private/gear?.stl",
                fallback: "Bambu-asset-7"
            ),
            "gear_.stl"
        )
        XCTAssertEqual(
            BambuUI.safeFilename("../..", fallback: "Bambu-asset-7"),
            "Bambu-asset-7"
        )
    }

    func testWarningsAreTrimmedAndDeduplicatedInOrder() {
        XCTAssertEqual(
            BambuUI.uniqueWarnings([" Missing plate. ", "", "Missing plate.", "Needs sign-in."]),
            ["Missing plate.", "Needs sign-in."]
        )
    }
}

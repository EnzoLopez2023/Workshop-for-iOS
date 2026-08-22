import XCTest
@testable import Workshop

final class ShippingResidueTests: XCTestCase {
    func testDefaultPaletteUsesSharedLivingPlanTokens() {
        XCTAssertEqual(Palette.spruce.canvas.light, LivingPlanTokens.canvas.light)
        XCTAssertEqual(Palette.spruce.canvas.dark, LivingPlanTokens.canvas.dark)
        XCTAssertEqual(Palette.spruce.action.light, LivingPlanTokens.spruceAction.light)
        XCTAssertEqual(Palette.spruce.action.dark, LivingPlanTokens.spruceAction.dark)
        XCTAssertEqual(Palette.spruce.danger.light, LivingPlanTokens.danger.light)
        XCTAssertEqual(Palette.spruce.danger.dark, LivingPlanTokens.danger.dark)
    }

    func testBuiltAppContainsNoCustomFontResources() throws {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        let contents = fileManager.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: Array(resourceKeys)
        )

        var customFonts: [String] = []
        while let url = contents?.nextObject() as? URL {
            guard try url.resourceValues(forKeys: resourceKeys).isRegularFile == true else { continue }
            if ["ttf", "otf", "woff", "woff2"].contains(url.pathExtension.lowercased()) {
                customFonts.append(url.path)
            }
        }

        XCTAssertTrue(customFonts.isEmpty, "Unexpected custom fonts in app bundle: \(customFonts)")
    }

    func testShippingSourceContainsNoRetiredVisualMarkers() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Shared",
            "Workshop",
            "WorkshopWidgets",
            "WorkshopShareExtension",
            "project.yml",
        ]
        let forbidden = [
            "Concourse",
            "MartianMonoBoard",
            "ArchivoWS",
            "UIAppFonts",
            "Theme.flap",
            "Theme.steel",
            "Theme.board",
            "WSWidget.flap",
            "WSWidget.steel",
            "SplitFlap",
        ]

        var findings: [String] = []
        for relativePath in paths {
            let url = repositoryRoot.appendingPathComponent(relativePath)
            for file in try sourceFiles(at: url) {
                let contents = try String(contentsOf: file, encoding: .utf8)
                for marker in forbidden where contents.localizedCaseInsensitiveContains(marker) {
                    findings.append("\(file.path): \(marker)")
                }
            }
        }

        XCTAssertTrue(findings.isEmpty, "Retired visual markers found:\n\(findings.joined(separator: "\n"))")
    }

    private func sourceFiles(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        if !isDirectory.boolValue {
            return [url]
        }

        let allowedExtensions = Set(["swift", "plist", "yml"])
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        var files: [URL] = []
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                  allowedExtensions.contains(file.pathExtension) else {
                continue
            }
            files.append(file)
        }
        return files
    }
}

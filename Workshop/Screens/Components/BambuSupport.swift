import Foundation
import NintekKit

extension BambuSourceSite {
    var workshopDisplayName: String {
        switch self {
        case .makerworld: "MakerWorld"
        case .thingiverse: "Thingiverse"
        case .printables: "Printables"
        case .unknown: "Other source"
        }
    }

    var workshopSymbol: String {
        switch self {
        case .makerworld: "globe.americas.fill"
        case .thingiverse: "shippingbox.fill"
        case .printables: "printer.fill"
        case .unknown: "cube.fill"
        }
    }
}

extension BambuAssetKind {
    var workshopDisplayName: String {
        switch self {
        case .image: "Image"
        case .model: "3D model"
        case .file, .unknown: "File"
        }
    }

    var workshopSymbol: String {
        switch self {
        case .image: "photo"
        case .model: "cube.fill"
        case .file, .unknown: "doc.fill"
        }
    }
}

extension BambuProject {
    var workshopImageAssets: [BambuAsset] {
        assets
            .filter { $0.kind == .image }
            .sorted(by: BambuUI.assetSort)
    }

    var workshopFileAssets: [BambuAsset] {
        assets
            .filter { $0.kind != .image }
            .sorted(by: BambuUI.assetSort)
    }
}

enum BambuUI {
    static func httpURL(_ rawValue: String?) -> URL? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    static func uniqueWarnings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    static func safeFilename(_ rawValue: String, fallback: String) -> String {
        let leaf = (rawValue as NSString).lastPathComponent
        let extensionValue = (leaf as NSString).pathExtension
        let stem = (leaf as NSString).deletingPathExtension
        let safeStem = sanitizedStem(stem).isEmpty ? sanitizedStem(fallback) : sanitizedStem(stem)
        let safeExtension = extensionValue.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()

        let limitedStem = String((safeStem.isEmpty ? "Bambu-file" : safeStem).prefix(120))
        guard !safeExtension.isEmpty else { return limitedStem }
        return "\(limitedStem).\(String(safeExtension.prefix(20)))"
    }

    static func assetSort(_ lhs: BambuAsset, _ rhs: BambuAsset) -> Bool {
        if lhs.sortOrder == rhs.sortOrder { return lhs.id < rhs.id }
        return lhs.sortOrder < rhs.sortOrder
    }

    private static func sanitizedStem(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_()[]"))
        var sanitized = value.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        let trimmed = sanitized.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))
        )
        return trimmed.rangeOfCharacter(from: .alphanumerics) == nil ? "" : trimmed
    }
}

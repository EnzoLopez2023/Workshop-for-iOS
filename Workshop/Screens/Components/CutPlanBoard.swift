import SwiftUI
import NintekKit

/// The cut plan's part colours, recoloured for the board world. NintekKit owns
/// the layout algorithm and assigns colours in a stable first-seen order; this
/// translates its palette index onto the board's signal set without touching
/// the shared package. Matches the web's `PALETTE` in `CutPlanSheet.tsx`, so a
/// plan drawn on the phone and one drawn in the browser read identically.
enum CutPlanBoard {
    static let palette = [
        "#D69A2E", "#5590B5", "#5E9E72", "#C4776B", "#8A78B8",
        "#B8792C", "#3C7695", "#3F8A64", "#A85348", "#6E5F9E",
    ]

    /// The sheet stock itself, and the ink printed on it. Both are fixed values
    /// rather than theme tokens: a cut plan is a document that gets exported to
    /// PDF and printed, so it must not follow the app's light/dark rendition.
    static let sheet = "#D5DBD8"
    static let ink = "#14181A"

    static func colorMap(_ layouts: [SheetLayout]) -> [String: String] {
        buildColorMap(layouts).mapValues { hex in
            guard let i = cutPlanPalette.firstIndex(of: hex) else { return palette[0] }
            return palette[i % palette.count]
        }
    }
}

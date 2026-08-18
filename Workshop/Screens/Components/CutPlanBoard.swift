import SwiftUI
import NintekKit

/// The cut plan's part colours, translated into the Living Plan Table world.
/// NintekKit owns
/// the layout algorithm and assigns colours in a stable first-seen order; this
/// translates its palette index without touching the shared package or layout.
enum CutPlanBoard {
    static let palette = [
        "#2F7D6E", "#5F8EA3", "#71905A", "#B87968", "#8072A3",
        "#3F9381", "#477A92", "#587D48", "#A56657", "#6D6292",
    ]

    /// The sheet stock itself, and the ink printed on it. Both are fixed values
    /// rather than theme tokens: a cut plan is a document that gets exported to
    /// PDF and printed, so it must not follow the app's light/dark rendition.
    static let sheet = "#F1F6F4"
    static let ink = "#15332E"

    static func colorMap(_ layouts: [SheetLayout]) -> [String: String] {
        buildColorMap(layouts).mapValues { hex in
            guard let i = cutPlanPalette.firstIndex(of: hex) else { return palette[0] }
            return palette[i % palette.count]
        }
    }
}

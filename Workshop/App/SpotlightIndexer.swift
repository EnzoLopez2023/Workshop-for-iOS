import CoreSpotlight
import Foundation
import NintekKit

/// Donates projects to on-device Spotlight search (Phase 6.3) — searching a
/// project's title in Spotlight and tapping the result opens it directly, no
/// network round-trip needed since the index is built from data the Dashboard
/// already loaded. Projects with a cut list get a second "Plan Cuts: …" entry
/// so the optimizer itself is one Spotlight search away, without needing a
/// full App-Intents entity-query for "run optimizer on a project".
enum SpotlightIndexer {
    @MainActor static func index(projects: [WSProject]) {
        var items: [CSSearchableItem] = []
        for p in projects {
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = p.title
            attrs.contentDescription = p.description
            attrs.keywords = p.woodTypes + p.toolsNeeded + [p.status.label, p.difficulty.rawValue]
            items.append(CSSearchableItem(uniqueIdentifier: "workshop://project/\(p.id)",
                                          domainIdentifier: "projects", attributeSet: attrs))

            if (p.partsCount ?? 0) > 0 {
                let cutAttrs = CSSearchableItemAttributeSet(contentType: .text)
                cutAttrs.title = "Plan Cuts: \(p.title)"
                cutAttrs.contentDescription = "Run the Cut Plan Optimizer for \(p.title)."
                items.append(CSSearchableItem(uniqueIdentifier: "workshop://project/\(p.id)?cutplan=1",
                                              domainIdentifier: "cutplans", attributeSet: cutAttrs))
            }
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    /// Removes every donated item — call on sign-out so a Spotlight search
    /// after switching accounts can't surface the previous user's projects.
    static func clear() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }
}

import Foundation
import ActivityKit
import NintekKit

/// Starts/ends the "shopping trip" Live Activity. Only one runs at a time —
/// starting a new one ends whichever was running. Mirrors
/// `CutListActivityController` exactly, including the same fixed race: `end()`
/// must be awaited *before* requesting the new activity, since a fire-and-forget
/// end() races `Activity.request` and can dismiss the activity just created.
@MainActor
enum ShoppingActivityController {
    static var isTracking: Bool {
        !Activity<ShoppingActivityAttributes>.activities.isEmpty
    }

    static func start(items: [ShoppingItem]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await end()
        let attrs = ShoppingActivityAttributes(
            items: items.map { .init(id: $0.id, name: $0.name, qtyLabel: $0.qtyLabel) }
        )
        do {
            _ = try Activity.request(attributes: attrs, content: .init(state: .init(), staleDate: nil))
        } catch {
            // Best-effort — Live Activities can fail to start for reasons
            // outside our control (disabled in Settings, budget exceeded, …).
        }
    }

    static func end() async {
        for activity in Activity<ShoppingActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

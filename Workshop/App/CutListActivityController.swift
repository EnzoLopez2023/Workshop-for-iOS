import Foundation
import ActivityKit
import NintekKit

/// Starts/ends the "tracking cuts right now" Live Activity for a project.
/// Only one runs at a time — starting a new one ends whichever was running.
@MainActor
enum CutListActivityController {
    static var isTracking: Bool {
        !Activity<CutListActivityAttributes>.activities.isEmpty
    }

    /// `end()`'s dismissal must be awaited *before* requesting the new
    /// activity — firing it as an untracked `Task` here races with
    /// `Activity.request` and can end up dismissing the activity we just
    /// created, since the fire-and-forget task doesn't actually run until
    /// after `request()` has already registered it.
    static func start(projectId: Int, projectTitle: String, cutList: [CutListItem]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await end()
        let attrs = CutListActivityAttributes(
            projectId: projectId, projectTitle: projectTitle,
            parts: cutList.map { .init(id: $0.id, partName: $0.partName, qty: $0.qty) }
        )
        do {
            _ = try Activity.request(attributes: attrs, content: .init(state: .init(), staleDate: nil))
        } catch {
            // Best-effort — Live Activities can fail to start for reasons
            // outside our control (disabled in Settings, budget exceeded, …).
        }
    }

    static func end() async {
        for activity in Activity<CutListActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

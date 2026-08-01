import Foundation
// BGTask/BGAppRefreshTask aren't Sendable-audited in the SDK yet; capturing
// one in an unstructured Task (unavoidable here — its own completion has to
// happen from inside the async work) needs the pre-concurrency import to
// downgrade that to a warning rather than a hard Swift 6 error.
@preconcurrency import BackgroundTasks
import WidgetKit
import NintekKit

/// Keeps the home-screen/Lock-Screen widgets from going stale between app
/// opens (Phase 7.9+) — without this, `SnapshotProvider`'s timeline just
/// re-reads the same App-Group snapshot every 30 minutes with no new data
/// underneath it, since nothing else ever refreshes it in the background.
enum BackgroundRefresh {
    static let taskIdentifier = "com.nintek.workshop.refresh"

    /// Registers the handler. Must run before the app finishes launching, so
    /// this is called from `AppDelegate.didFinishLaunching`, not lazily.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task as! BGAppRefreshTask)
        }
    }

    /// Requests the next run. The system decides the actual timing (rarely
    /// sooner than a few hours); call this after every foreground refresh too,
    /// since a completed/expired task doesn't reschedule itself.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        scheduleNext()
        let refresh = Task {
            await refreshSnapshot()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { refresh.cancel() }
    }

    /// A throwaway `AppModel` gives the exact same signed-in/token-provider
    /// selection `AppModel.init()` already does (Apple session vs. MSAL vs.
    /// signed-out) — no separate background auth path to keep in sync.
    @MainActor
    private static func refreshSnapshot() async {
        let model = AppModel()
        guard model.isSignedIn else { return }
        do {
            async let p = model.api.listProjects()
            async let s = model.api.shoppingList()
            let (projects, shopping) = try await (p, s)
            var snapshot = WorkshopWidgetSnapshot(projects: projects)
            snapshot.shoppingItems = shopping.prefix(5).map {
                .init(id: $0.id, name: $0.name, qtyLabel: $0.qtyLabel)
            }
            WorkshopWidgetStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            NSLog("[Workshop] Background widget refresh failed: %@", error.localizedDescription)
        }
    }
}

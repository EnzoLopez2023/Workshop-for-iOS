import UIKit
// UNUserNotificationCenterDelegate's protocol requirements aren't
// Sendable-audited in the SDK yet; @preconcurrency downgrades the resulting
// actor-isolation mismatch to a warning rather than a hard Swift 6 error.
@preconcurrency import UserNotifications

/// A thin UIKit delegate for the handful of things SwiftUI's pure `App`
/// lifecycle has no hook for: registering the background-refresh task before
/// launch finishes, becoming the notification center's delegate (for the
/// finish-reminder Snooze action), and reading a Home Screen Quick Action.
/// Deliberately does *not* take over scene management with a custom
/// `UISceneDelegate` class — that would risk breaking SwiftUI's own window
/// bridging — so a warm/backgrounded relaunch's `windowScene(_:performActionFor:)`
/// hot path is intentionally left unhandled; the quick action still opens the
/// app, it just won't route anywhere extra in that case.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefresh.register()

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([FinishReminderScheduler.notificationCategory])

        return true
    }

    /// For a scene-based app (this one has an `Application Scene Manifest`,
    /// required for iPad/Mac multiwindow), a cold-launch shortcut item does
    /// NOT arrive via `didFinishLaunchingWithOptions`'s `launchOptions` — that
    /// key is a pre-scene-lifecycle artifact iOS no longer populates once a
    /// scene manifest is present. It arrives on `options.shortcutItem` here
    /// instead. Returning a configuration built from the session's own
    /// existing config (no custom `delegateClass`) keeps SwiftUI's default
    /// scene bridging intact — this only *observes* the shortcut, it doesn't
    /// take over scene creation.
    func application(_ application: UIApplication,
                      configurationForConnecting connectingSceneSession: UISceneSession,
                      options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            Self.handle(shortcutItem)
        }
        return UISceneConfiguration(name: connectingSceneSession.configuration.name, sessionRole: connectingSceneSession.role)
    }

    @MainActor
    static func handle(_ shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
        case "com.nintek.workshop.newproject": IntentRouter.shared.request(.newProject)
        case "com.nintek.workshop.shoppinglist": IntentRouter.shared.request(.shopping)
        default: break
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// "Snooze 1 Day" on the finish-reminder notification — reschedules the
    /// same identifier 24h out rather than opening the app, since there's
    /// nothing in the data model to "mark done" against (see
    /// `FinishReminderScheduler`).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             didReceive response: UNNotificationResponse,
                                             withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == FinishReminderScheduler.snoozeActionIdentifier {
            FinishReminderScheduler.snooze(response.notification.request)
        }
        completionHandler()
    }

    /// Show the banner even while the app is foregrounded — otherwise a
    /// reminder that fires while Workshop happens to be open is silently
    /// dropped, since the default is to suppress foreground alerts.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

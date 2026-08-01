import Foundation
import UserNotifications
import NintekKit

/// "Time for another coat" local reminders computed from finish-log data
/// (Phase 7.7) — no push infrastructure needed, just a local notification
/// scheduled a fixed interval after the entry's applied date. The data model
/// has no per-product cure time, so this uses one reasonable default
/// interval rather than trying to model every finish's actual recoat window.
enum FinishReminderScheduler {
    private static let recoatInterval: TimeInterval = 24 * 60 * 60

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedules (or re-schedules, since the identifier is stable per entry)
    /// a reminder for one finish-log entry — a no-op for single-coat entries
    /// or applied dates too far in the past for the window to still make sense.
    ///
    /// `add(_:withCompletionHandler:)` reports no error when notifications are
    /// denied — it just silently drops the request rather than persisting it —
    /// so this is the only place a scheduling failure is actually observable.
    static func schedule(_ entry: FinishLogEntry, projectTitle: String) {
        let identifier = "finish-reminder-\(entry.id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let coats = entry.coats, coats >= 2,
              let appliedDate = parseDate(entry.appliedAt) else { return }
        let fireDate = appliedDate.addingTimeInterval(recoatInterval)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for another coat"
        content.body = "\(entry.productName) on \(projectTitle) is ready for its next coat."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) { error in
            if let error {
                NSLog("[Workshop] FinishReminderScheduler: failed to schedule %@ — %@", identifier, error.localizedDescription)
            }
        }
    }

    static func cancel(_ entry: FinishLogEntry) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["finish-reminder-\(entry.id)"])
    }

    private static func parseDate(_ raw: String) -> Date? {
        Self.ymdParser.date(from: String(raw.prefix(10)))
    }

    private static let ymdParser: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
}

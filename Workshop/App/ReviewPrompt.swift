import Foundation

/// Local throttle for `requestReview()` calls (Phase 7.9+). StoreKit itself
/// caps how often the system dialog can actually appear (roughly 3x/365
/// days), but that's a display limit, not a reason to call the API on every
/// save of an already-completed project — this keeps the call itself tied to
/// genuine milestones.
enum ReviewPrompt {
    private static let key = "ws.lastReviewPromptAt"
    private static let minInterval: TimeInterval = 45 * 24 * 60 * 60

    static func shouldAsk() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return true }
        return Date().timeIntervalSince(last) > minInterval
    }

    static func recordAsked() {
        UserDefaults.standard.set(Date(), forKey: key)
    }
}

import UIKit

/// One-shot haptic cues for moments a `.sensoryFeedback` trigger can't
/// cleanly observe — e.g. right before a view dismisses on save, where the
/// view tears down the same frame the trigger would change. Value-bound cases
/// (toggles, a result appearing) use SwiftUI's `.sensoryFeedback` modifier
/// directly instead — see `CutPlanOptimizerView`, `ProjectDetailView`.
enum Haptics {
    @MainActor static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    @MainActor static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

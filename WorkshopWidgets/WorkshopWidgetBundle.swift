import WidgetKit
import SwiftUI

/// The Workshop widget extension's entry point. Groups every widget the app
/// vends: home-screen project stats, the in-progress projects list, the
/// interactive shopping-list checkoff widget, the Lock Screen/StandBy
/// complication, and the "tracking cuts" / "shopping trip" Live Activities.
@main
struct WorkshopWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        InProgressWidget()
        ShoppingListWidget()
        LockScreenWidget()
        CutListActivityWidget()
        ShoppingActivityWidget()
    }
}

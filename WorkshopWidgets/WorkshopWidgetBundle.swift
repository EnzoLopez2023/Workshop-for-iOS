import WidgetKit
import SwiftUI

/// The Workshop widget extension's entry point. Groups every widget the app
/// vends: home-screen project stats, the in-progress projects list, and the
/// "tracking cuts" Live Activity.
@main
struct WorkshopWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        InProgressWidget()
        CutListActivityWidget()
    }
}

import WidgetKit
import SwiftUI

/// The Workshop widget extension's entry point. Groups every widget the app
/// vends: home-screen project stats and the in-progress projects list.
@main
struct WorkshopWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        InProgressWidget()
    }
}

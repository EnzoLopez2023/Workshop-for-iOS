import Foundation

/// Handoff between Enzo's own iPhone/iPad/Mac — declared in `NSUserActivityTypes`
/// (project.yml) and advertised by `ProjectDetailView`, continued in
/// `WorkshopApp`'s `.onContinueUserActivity` by reusing the exact same
/// `workshop://project/<id>` routing the widgets/Spotlight/deep-links already do.
enum HandoffActivity {
    static let viewingProject = "com.nintek.workshop.viewing-project"
    static let projectIdKey = "projectId"
}

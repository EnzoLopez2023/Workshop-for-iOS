import Foundation

/// `@AppStorage` keys shared between `MoreView` (where they're set) and the
/// screens that read them (`DashboardView`, `ProjectFormView`) — parity with
/// the web's `SettingsContext.tsx`.
enum SettingsKeys {
    static let defaultProjectStatus = "ws.defaultProjectStatus"
    static let dashboardSort = "ws.dashboardSort"
    static let showCompletedByDefault = "ws.showCompletedByDefault"
}

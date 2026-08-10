import Foundation

/// `@AppStorage` keys shared between `MoreView` (where they're set) and the
/// screens that read them (`DashboardView`, `ProjectFormView`) — parity with
/// the web's `SettingsContext.tsx`.
enum SettingsKeys {
    static let defaultProjectStatus = "ws.defaultProjectStatus"
    static let dashboardSort = "ws.dashboardSort"
    static let showCompletedByDefault = "ws.showCompletedByDefault"
    /// `TextSize.rawValue` (1–5). See `TextSize` in Theme.swift.
    static let textSize = "ws.textSize"

    /// The on/off "Large Text" switch `textSize` replaced.
    private static let legacyLargeText = "ws.fontSizeLarge"

    /// Carries the old switch onto the five-step scale — off was step 2, on was
    /// step 3 — so an upgrading user keeps the size they chose instead of
    /// landing on the new default. Runs once; the old key is removed after.
    static func migrateLegacyTextSize(_ defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: textSize) == nil,
              let wasLarge = defaults.object(forKey: legacyLargeText) as? Bool else { return }
        defaults.set((wasLarge ? TextSize.three : .two).rawValue, forKey: textSize)
        defaults.removeObject(forKey: legacyLargeText)
    }
}

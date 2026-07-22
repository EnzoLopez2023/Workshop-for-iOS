import SwiftUI

/// Workshop's visual identity: warm cream + rust + ink, matching the web app.
/// Color tokens resolve from the *active palette* (`ThemeManager.shared`), so the
/// whole app re-skins when the user picks a new accent. Each token is light/dark
/// adaptive via `WSColor`. Typography is the system font throughout (no serif),
/// a deliberate native choice.
enum Theme {
    /// The currently selected palette (accent).
    static var palette: Palette { ThemeManager.shared.palette }

    // Surfaces
    static var cream: Color     { palette.cream.color }      // app background
    static var creamSoft: Color { palette.creamSoft.color }  // secondary background
    static var paper: Color     { palette.paper.color }      // cards

    // Text
    static var ink: Color     { palette.ink.color }      // headings
    static var inkSoft: Color { palette.inkSoft.color }  // body
    static var subtle: Color  { palette.subtle.color }   // muted / secondary

    // Lines + accent
    static var line: Color        { palette.line.color }
    static var lineStrong: Color  { palette.lineStrong.color }
    static var accent: Color      { palette.accent.color }
    static var accentDeep: Color  { palette.accentDeep.color }
    static var accentSoft: Color  { palette.accentSoft.color }

    // Semantic status
    static var excellent: Color { palette.excellent.color }
    static var good: Color      { palette.good.color }
    static var amber: Color     { palette.amber.color }
    static var emerald: Color   { palette.emerald.color }
    static var fail: Color      { palette.fail.color }

    /// Display face for headings. The app uses **one** typeface throughout — the
    /// system font (San Francisco). Kept as a helper (rather than inline
    /// `.system`) so heading weight/size stays consistent and easy to retune.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    /// Style navigation + tab bars to the warm palette (system font titles).
    /// Main-actor — it mutates UIKit appearance proxies.
    @MainActor
    static func configureAppearance() {
        let inkColor = palette.ink.uiColor
        let creamColor = palette.cream.uiColor

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = creamColor
        nav.shadowColor = .clear
        nav.largeTitleTextAttributes = [.font: UIFont.systemFont(ofSize: 32, weight: .bold), .foregroundColor: inkColor]
        nav.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: inkColor]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = creamColor
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - Shared components

extension View {
    /// Editorial card — paper surface, hairline border, soft lift shadow (matches
    /// the web `--shadow-card`).
    func wsCard() -> some View {
        self
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1))
            .shadow(color: Color(red: 0.23, green: 0.14, blue: 0.06).opacity(0.12), radius: 10, x: 0, y: 6)
    }

    func creamBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.cream.ignoresSafeArea())
    }

    /// Constrain content to a readable/card column, centered. On iPad (regular
    /// width) the cap keeps cards from stretching; on iPhone the cap exceeds the
    /// screen so content stays full-width.
    func contentColumn(_ maxWidth: CGFloat = 640) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

/// App version/build, shown in the sidebar footer and Settings.
enum AppInfo {
    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }
}

/// Uppercase, letter-spaced rust eyebrow — the web app's section label.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold)).tracking(1.6)
            .foregroundStyle(Theme.accent)
    }
}

/// Light/dark/system appearance override (persisted; applied in RootView).
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self { case .light: .light; case .dark: .dark; case .system: nil }
    }
}

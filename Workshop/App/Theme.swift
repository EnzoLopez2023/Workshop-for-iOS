import SwiftUI
import UIKit

/// Living Plan Table: cool vellum, layered native glass, spruce drawing ink,
/// pencil annotations, system typography, and continuous iOS geometry.
///
/// Legacy token/helper names remain source-compatible while screens migrate,
/// but every value and primitive resolves into the approved visual world.
enum Theme {
    /// The currently selected annotation palette.
    static var palette: Palette { ThemeManager.shared.palette }

    // MARK: Surfaces

    static var concourse: Color { palette.concourse.color }  // plan canvas
    static var flapShade: Color { palette.flapShade.color }  // recessed layer
    static var flap: Color      { palette.flap.color }       // raised layer

    // MARK: Text

    static var ink: Color     { palette.ink.color }
    static var muted: Color   { palette.muted.color }    // secondary

    // MARK: Structure

    static var line: Color       { palette.line.color }
    static var steel: Color      { palette.steel.color }
    static var steelDark: Color  { palette.steelDark.color }
    static var steelLight: Color { palette.steelLight.color }
    static var onSteel: Color    { palette.onSteel.color }

    // MARK: Annotation + semantic color

    static var accent: Color     { palette.accent.color }
    static var accentDeep: Color { palette.accentDeep.color }
    static var accentFill: Color { palette.accentFill.color }
    static var pencil: Color     { Palette.beacon.accent.color }
    static var green: Color      { palette.green.color }
    static var greenFill: Color  { palette.greenFill.color }
    static var red: Color        { palette.red.color }
    static var redFill: Color    { palette.redFill.color }

    /// Faint wash of an annotation color, for row tinting.
    static func tint(_ color: Color) -> Color { color.opacity(0.11) }

    // MARK: Compatibility surfaces

    static var flapFace: Color   { palette.flapFace.color }
    static var flapFaceLo: Color { palette.flapFaceLo.color }
    static var flapLetter: Color { palette.flapLetter.color }

    /// Navigation material fallback behind native blur.
    static var steelFace: LinearGradient {
        LinearGradient(colors: [steelLight.opacity(0.96), steel.opacity(0.82)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Soft metric tile gradient retained for compatibility.
    static var flapFaceGradient: LinearGradient {
        LinearGradient(colors: [flapFace, flapFaceLo],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: Radii

    static let rFlap: CGFloat = 10
    static let rPanel: CGFloat = 14
    static let rHero: CGFloat = 24

    // MARK: Typography

    /// Compatibility entry point for former board labels. It now resolves to
    /// SF Rounded so labels stay native, open, and Dynamic Type-aware.
    static func board(_ size: CGFloat, _ weight: BoardWeight = .semibold,
                      relativeTo style: Font.TextStyle = .body) -> Font {
        .system(
            size: scaledSize(size, relativeTo: style),
            weight: weight.fontWeight,
            design: .rounded
        )
    }

    /// Fixed sample type used only by the text-size picker.
    static func boardFixed(_ size: CGFloat, _ weight: BoardWeight = .semibold) -> Font {
        .system(size: size, weight: weight.fontWeight, design: .rounded)
    }

    /// Native SF Pro for body copy and controls.
    static func ui(_ size: CGFloat, _ weight: UIWeight = .regular,
                   relativeTo style: Font.TextStyle = .body) -> Font {
        .system(
            size: scaledSize(size, relativeTo: style),
            weight: weight.fontWeight,
            design: .default
        )
    }

    enum BoardWeight {
        case regular, semibold, bold
        var fontWeight: Font.Weight {
            switch self {
            case .regular:  .regular
            case .semibold: .semibold
            case .bold:     .bold
            }
        }
    }

    enum UIWeight {
        case regular, medium, bold
        var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium:  .medium
            case .bold:    .bold
            }
        }
    }

    /// Rounded system display face for project titles and focal moments.
    static func display(_ size: CGFloat, _ weight: BoardWeight = .bold) -> Font {
        .system(
            size: scaledSize(size, relativeTo: .title),
            weight: weight.fontWeight,
            design: .rounded
        )
    }

    private static func scaledSize(_ size: CGFloat, relativeTo style: Font.TextStyle) -> CGFloat {
        UIFontMetrics(forTextStyle: uiTextStyle(style)).scaledValue(for: size)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }

    // MARK: UIKit chrome

    /// Native material navigation and tab chrome. Main-actor because UIKit
    /// appearance proxies are global mutable state.
    @MainActor
    static func configureAppearance() {
        let inkColor = palette.ink.uiColor
        let mutedColor = palette.muted.uiColor
        let accentColor = palette.accentDeep.uiColor
        let largeFont = roundedUIFont(size: 34, weight: .bold)
        let titleFont = roundedUIFont(size: 17, weight: .semibold)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        nav.backgroundColor = palette.flap.uiColor.withAlphaComponent(0.58)
        nav.shadowColor = palette.line.uiColor.withAlphaComponent(0.45)
        nav.largeTitleTextAttributes = [
            .font: largeFont, .foregroundColor: inkColor,
        ]
        nav.titleTextAttributes = [
            .font: titleFont, .foregroundColor: inkColor,
        ]
        let navButton = UIBarButtonItemAppearance(style: .plain)
        navButton.normal.titleTextAttributes = [.font: titleFont, .foregroundColor: accentColor]
        nav.buttonAppearance = navButton
        nav.backButtonAppearance = navButton
        nav.doneButtonAppearance = navButton
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accentColor

        let tabFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tab.backgroundColor = palette.flap.uiColor.withAlphaComponent(0.66)
        tab.shadowColor = palette.line.uiColor.withAlphaComponent(0.5)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: tabFont, .foregroundColor: mutedColor]
            item.normal.iconColor = mutedColor
            item.selected.titleTextAttributes = [.font: tabFont, .foregroundColor: inkColor]
            item.selected.iconColor = accentColor
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    private static func roundedUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Shared components

/// A compact glass toolbar control. The legacy tone names remain to avoid
/// churn at call sites: `.amber` is the primary annotation action.
struct BoardToolbarButton: View {
    let symbol: String
    let label: String
    var tone: Tone = .steel
    let action: () -> Void

    enum Tone { case amber, steel, danger }

    private var glyph: Color {
        switch tone {
        case .steel: Theme.accentDeep
        case .amber, .danger: .white
        }
    }

    @ViewBuilder private var buttonBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
        switch tone {
        case .amber:
            shape.fill(Theme.accentDeep)
        case .steel:
            shape.fill(.clear)
        case .danger:
            shape.fill(Theme.redFill)
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: 38, height: 38)
                .background { buttonBackground }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                        .strokeBorder(.clear, lineWidth: 1)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlanPressButtonStyle())
        .accessibilityLabel(label)
    }
}

extension ToolbarContent {
    /// Compatibility hook retained for call sites. Living Plan Table embraces
    /// the system's shared toolbar material instead of hiding it.
    @ToolbarContentBuilder func boardToolbarItem() -> some ToolbarContent {
        self
    }
}

extension View {
    /// A standard frosted layer with the approved 14-point continuous squircle.
    func planGlass(cornerRadius: CGFloat = Theme.rPanel, elevated: Bool = true) -> some View {
        self
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
            )
            .shadow(
                color: Theme.steelDark.opacity(elevated ? 0.12 : 0),
                radius: elevated ? 16 : 0,
                x: 0,
                y: elevated ? 8 : 0
            )
    }

    /// Compatibility card modifier, now rendered as a raised tracing layer.
    func wsCard() -> some View {
        self
            .padding(16)
            .planGlass()
    }

    /// The vellum plan canvas behind scrolling content.
    func boardBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PlanCanvasBackground().ignoresSafeArea())
    }

    /// Constrain content to a readable/card column, centered — see
    /// ``ContentColumnLayout`` for how a wide screen is handled.
    func contentColumn(_ maxWidth: CGFloat = 640) -> some View {
        ContentColumnLayout(maxWidth: maxWidth) { self }
    }

    /// Apple's minimum interactive target.
    func minimumHitTarget() -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

private struct PlanPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PlanCanvasBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.concourse, Theme.flapShade.opacity(0.72), Theme.concourse],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                var path = Path()
                let spacing: CGFloat = 24
                for x in stride(from: 0, through: size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(Theme.line.opacity(0.18)), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The reading column. Content is capped so cards don't stretch into ribbons,
/// but a hard cap turns a landscape iPad into a
/// narrow app with two dead bands beside it. So wherever the space is wider
/// than the cap, the column hands back a third of the empty margin: still a
/// column, noticeably less blank. Where there's no slack (any phone in
/// portrait) this is a no-op and content stays full-width.
///
/// This is a `Layout` rather than a `.frame(maxWidth:)` because it needs the
/// width actually *proposed* to the content (inside the screen's padding), and
/// a `GeometryReader` would take the whole space instead of measuring it.
struct ContentColumnLayout: Layout {
    let maxWidth: CGFloat
    /// Share of the leftover margin the column reclaims.
    private let reclaim: CGFloat = 0.33

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let available = available(in: proposal)
        let height = subviews.first?
            .sizeThatFits(ProposedViewSize(width: columnWidth(in: available), height: proposal.height))
            .height ?? 0
        return CGSize(width: available, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        subview.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                      proposal: ProposedViewSize(width: columnWidth(in: bounds.width), height: bounds.height))
    }

    private func available(in proposal: ProposedViewSize) -> CGFloat {
        guard let width = proposal.width, width.isFinite, width > 0 else { return maxWidth }
        return width
    }

    private func columnWidth(in available: CGFloat) -> CGFloat {
        min(available, available * reclaim + maxWidth * (1 - reclaim))
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

// MARK: - Shared content primitives

/// Open section heading with an optional count and trailing action.
struct Rail<Trailing: View>: View {
    let title: String
    let count: Int?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, count: Int? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            trailing
            if let count {
                Text(count.formatted())
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Theme.tint(Theme.accent),
                        in: Capsule()
                    )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}

extension Rail where Trailing == EmptyView {
    init(_ title: String, count: Int? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

/// Compact semantic label used above values and within cards.
struct BoardCaps: View {
    let text: String
    var size: CGFloat = 10
    var color: Color?
    init(_ text: String, size: CGFloat = 10, color: Color? = nil) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text)
            .font(
                .system(
                    size: size,
                    weight: size >= 13 ? .semibold : .medium,
                    design: .rounded
                )
            )
            .foregroundStyle(color ?? (size >= 13 ? Theme.ink : Theme.muted))
    }
}

/// Compact value with tabular figures where applicable.
struct Readout: View {
    let text: String
    var size: CGFloat = 15
    var color: Color?
    init(_ text: String, size: CGFloat = 15, color: Color? = nil) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color ?? Theme.ink)
    }
}

/// Status capsule with semantic color and a text label.
struct Flag: View {
    enum Tone { case idle, steel, amber, green, red }
    let text: String
    let tone: Tone

    init(_ text: String, tone: Tone = .idle) { self.text = text; self.tone = tone }

    private var background: Color {
        switch tone {
        case .idle:  Theme.flapShade.opacity(0.9)
        case .steel: Theme.tint(Theme.accent)
        case .amber: Theme.accentDeep
        case .green: Theme.tint(Theme.green)
        case .red:   Theme.tint(Theme.red)
        }
    }

    private var foreground: Color {
        switch tone {
        case .idle:  Theme.muted
        case .steel: Theme.accentDeep
        case .amber: .white
        case .green: Theme.green
        case .red:   Theme.red
        }
    }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        tone == .idle ? Theme.line.opacity(0.7) : .clear,
                        lineWidth: 1
                    )
            )
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

/// Compatibility style that now delegates to the native iOS switch.
struct FlapToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(
            isOn: Binding(
                get: { configuration.isOn },
                set: { configuration.isOn = $0 }
            )
        ) {
            configuration.label
        }
        .toggleStyle(.switch)
        .tint(Theme.accentDeep)
    }
}

extension ToggleStyle where Self == FlapToggleStyle {
    static var flap: FlapToggleStyle { FlapToggleStyle() }
}

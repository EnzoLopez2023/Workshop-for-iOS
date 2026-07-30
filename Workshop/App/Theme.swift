import SwiftUI

/// Workshop's visual identity: the **Concourse Board** — a Solari rail departure
/// board rendered as a woodworking record. Cool concourse ground, bone flap
/// faces, brushed steel frames, and a single lit signal lamp.
///
/// Color tokens resolve from the *active palette* (`ThemeManager.shared`), so the
/// whole app re-lamps when the user picks a new signal. Each token is light/dark
/// adaptive via `WSColor`; dark is the board's own night form, not an inversion.
///
/// Typography is two bundled families — Martian Mono Board for every piece of
/// board lettering, Archivo for prose. Both scale with Dynamic Type.
enum Theme {
    /// The currently selected palette (signal lamp).
    static var palette: Palette { ThemeManager.shared.palette }

    // MARK: Surfaces

    static var concourse: Color { palette.concourse.color }  // app background
    static var flapShade: Color { palette.flapShade.color }  // recessed surface
    static var flap: Color      { palette.flap.color }       // cards

    // MARK: Text

    static var ink: Color     { palette.ink.color }      // headings, board lettering
    static var muted: Color   { palette.muted.color }    // secondary

    // MARK: Structure

    static var line: Color       { palette.line.color }
    static var steel: Color      { palette.steel.color }
    static var steelDark: Color  { palette.steelDark.color }
    static var steelLight: Color { palette.steelLight.color }
    static var onSteel: Color    { palette.onSteel.color }

    // MARK: Signals

    static var accent: Color     { palette.accent.color }
    static var accentDeep: Color { palette.accentDeep.color }
    static var accentFill: Color { palette.accentFill.color }
    static var green: Color      { palette.green.color }
    static var greenFill: Color  { palette.greenFill.color }
    static var red: Color        { palette.red.color }
    static var redFill: Color    { palette.redFill.color }

    /// Faint wash of a signal, for row tinting.
    static func tint(_ color: Color) -> Color { color.opacity(0.11) }

    // MARK: Flap modules

    static var flapFace: Color   { palette.flapFace.color }
    static var flapFaceLo: Color { palette.flapFaceLo.color }
    static var flapLetter: Color { palette.flapLetter.color }

    /// The brushed vertical gradient every steel band and frame carries.
    static var steelFace: LinearGradient {
        LinearGradient(colors: [steelLight, steel, steelDark],
                       startPoint: .top, endPoint: .bottom)
    }

    /// A flap module's face — lighter above the split, darker below.
    static var flapFaceGradient: LinearGradient {
        LinearGradient(colors: [flapFace, flapFaceLo],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: Radii

    /// Nothing in this world is rounder than a real flap edge.
    static let rFlap: CGFloat = 2
    static let rPanel: CGFloat = 3

    // MARK: Typography

    /// Board lettering — every label, title, and readout. Martian Mono at width
    /// 82, baked in (SwiftUI has no `font-stretch`).
    static func board(_ size: CGFloat, _ weight: BoardWeight = .semibold,
                      relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.faceName, size: size, relativeTo: style)
    }

    /// Prose. Archivo — used for descriptions and body copy only, never for
    /// board lettering.
    static func ui(_ size: CGFloat, _ weight: UIWeight = .regular,
                   relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.faceName, size: size, relativeTo: style)
    }

    enum BoardWeight {
        case regular, semibold, bold
        var faceName: String {
            switch self {
            case .regular:  "MartianMonoBoard-Regular"
            case .semibold: "MartianMonoBoard-SemiBold"
            case .bold:     "MartianMonoBoard-Bold"
            }
        }
    }

    enum UIWeight {
        case regular, medium, bold
        var faceName: String {
            switch self {
            case .regular: "ArchivoWS-Regular"
            case .medium:  "ArchivoWS-Medium"
            case .bold:    "ArchivoWS-Bold"
            }
        }
    }

    /// Display face for screen titles — board lettering at heading weight.
    static func display(_ size: CGFloat, _ weight: BoardWeight = .bold) -> Font {
        board(size, weight, relativeTo: .title)
    }

    // MARK: UIKit chrome

    /// Style navigation + tab bars as the board's steel header band.
    /// Main-actor — it mutates UIKit appearance proxies.
    @MainActor
    static func configureAppearance() {
        let steelColor = palette.steel.uiColor
        let onSteelColor = palette.onSteel.uiColor
        let concourseColor = palette.concourse.uiColor
        let mutedColor = palette.muted.uiColor
        let lampColor = palette.accentFill.uiColor

        // Board lettering in the bars, falling back to the system face if the
        // bundled font is somehow unavailable.
        let largeFont = UIFont(name: "MartianMonoBoard-Bold", size: 25)
            ?? .systemFont(ofSize: 25, weight: .bold)
        let titleFont = UIFont(name: "MartianMonoBoard-SemiBold", size: 14)
            ?? .systemFont(ofSize: 14, weight: .semibold)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = steelColor
        nav.shadowColor = .clear
        nav.largeTitleTextAttributes = [
            .font: largeFont, .foregroundColor: onSteelColor, .kern: 0.5,
        ]
        nav.titleTextAttributes = [
            .font: titleFont, .foregroundColor: onSteelColor, .kern: 1.2,
        ]
        let navButton = UIBarButtonItemAppearance(style: .plain)
        navButton.normal.titleTextAttributes = [.font: titleFont, .foregroundColor: onSteelColor]
        nav.buttonAppearance = navButton
        nav.backButtonAppearance = navButton
        nav.doneButtonAppearance = navButton
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = lampColor

        // The tab bar reads as the concourse floor rail rather than a second
        // steel band, so the two bars don't fight each other.
        let tabFont = UIFont(name: "MartianMonoBoard-SemiBold", size: 10)
            ?? .systemFont(ofSize: 10, weight: .semibold)
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = concourseColor
        tab.shadowColor = palette.line.uiColor
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: tabFont, .foregroundColor: mutedColor, .kern: 0.6]
            item.normal.iconColor = mutedColor
            item.selected.titleTextAttributes = [.font: tabFont, .foregroundColor: palette.ink.uiColor, .kern: 0.6]
            item.selected.iconColor = palette.accentDeep.uiColor
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - Shared components

/// A toolbar control as a flap on the steel band: square, flat, and either the
/// amber lamp (the screen's one primary action) or a recessed steel plate.
struct BoardToolbarButton: View {
    let symbol: String
    let label: String
    var tone: Tone = .steel
    let action: () -> Void

    enum Tone { case amber, steel, danger }

    private var fill: Color {
        switch tone {
        case .amber:  Theme.accentFill
        case .steel:  Theme.steelLight
        case .danger: Theme.redFill
        }
    }

    private var glyph: Color {
        tone == .amber ? Theme.steelDark : Theme.onSteel
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(glyph)
                .frame(width: 30, height: 30)
                .background(fill, in: RoundedRectangle(cornerRadius: Theme.rFlap))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension ToolbarContent {
    /// iOS 26 gives toolbar items a glass capsule. The board has no capsules and
    /// its buttons carry their own flap background, so the shared one is hidden
    /// where the OS offers the choice.
    @ToolbarContentBuilder func boardToolbarItem() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

extension View {
    /// A flap card — flat bone face, hairline frame, no lift. Real flaps sit in
    /// a frame; they don't float, so this carries no drop shadow.
    func wsCard() -> some View {
        self
            .padding(14)
            .background(Theme.flap)
            .overlay(
                Rectangle().strokeBorder(Theme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }

    /// The concourse ground behind a scroll view.
    func boardBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.concourse.ignoresSafeArea())
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

// MARK: - Board primitives

/// A steel section header — the board's own way of naming a block of rows.
/// This replaces the old floating `Eyebrow`: on a real board a heading is a
/// physical bar above the rows, not a small tinted word.
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
            Text(title.uppercased())
                .font(Theme.board(11, .semibold, relativeTo: .caption))
                .tracking(1.4)
                .foregroundStyle(Theme.onSteel)
            Spacer(minLength: 8)
            trailing
            if let count {
                Text(String(format: "%02d", count))
                    .font(Theme.board(11, .bold, relativeTo: .caption))
                    .tracking(0.8)
                    .foregroundStyle(Theme.accentFill)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.steelFace)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
    }
}

extension Rail where Trailing == EmptyView {
    init(_ title: String, count: Int? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

/// Small uppercase board lettering — the label above a value.
struct BoardCaps: View {
    let text: String
    var size: CGFloat = 10
    var color: Color?
    init(_ text: String, size: CGFloat = 10, color: Color? = nil) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(Theme.board(size, .semibold, relativeTo: size >= 13 ? .headline : .caption2))
            .tracking(size >= 13 ? 0.6 : 1.1)
            .foregroundStyle(color ?? (size >= 13 ? Theme.ink : Theme.muted))
    }
}

/// A value as the board would print it — mono, tight, tabular.
struct Readout: View {
    let text: String
    var size: CGFloat = 15
    var color: Color?
    init(_ text: String, size: CGFloat = 15, color: Color? = nil) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text)
            .font(Theme.board(size, .semibold, relativeTo: .body))
            .monospacedDigit()
            .foregroundStyle(color ?? Theme.ink)
    }
}

/// A signal flag — the board's status marker. Square-cornered, filled, and
/// lettered in board caps.
struct Flag: View {
    enum Tone { case idle, steel, amber, green, red }
    let text: String
    let tone: Tone

    init(_ text: String, tone: Tone = .idle) { self.text = text; self.tone = tone }

    private var background: Color {
        switch tone {
        case .idle:  Theme.flapShade
        case .steel: Theme.steel
        case .amber: Theme.accentFill
        case .green: Theme.greenFill
        case .red:   Theme.redFill
        }
    }

    private var foreground: Color {
        switch tone {
        case .idle:  Theme.muted
        // The amber lamp is bright enough that ink reads better than paper on it.
        case .amber: Color(uiColor: UIColor(rgb: 0x14181A))
        default:     Theme.onSteel
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.board(9.5, .bold, relativeTo: .caption2))
            .tracking(0.9)
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rFlap)
                    .strokeBorder(tone == .idle ? Theme.line : .clear, lineWidth: 1)
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

/// A toggle rendered as a two-cell flap module: the switch *is* a flap that
/// turns over between OFF and ON, split line and all. The system capsule has no
/// place on a board — and a switch is exactly the thing a real Solari unit does.
struct FlapToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Button {
                configuration.isOn.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.rFlap)
                        .fill(Theme.flapFaceGradient)
                    // The split line every flap on this board carries.
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .frame(height: 1)
                    Text(configuration.isOn ? "ON" : "OFF")
                        .font(Theme.board(11, .bold))
                        .tracking(1.2)
                        .foregroundStyle(configuration.isOn ? Theme.accentFill : Theme.flapLetter.opacity(0.55))
                        .contentTransition(.identity)
                        .id(configuration.isOn)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)))
                }
                .frame(width: 52, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rFlap)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
                .animation(.easeIn(duration: 0.11), value: configuration.isOn)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
        }
    }
}

extension ToggleStyle where Self == FlapToggleStyle {
    static var flap: FlapToggleStyle { FlapToggleStyle() }
}

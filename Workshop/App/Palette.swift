import SwiftUI
import UIKit

// MARK: - Adaptive token

/// A single design token carrying a light + dark hex value. Resolves to an
/// adaptive `Color`/`UIColor` that follows the active `colorScheme`.
struct WSColor {
    let light: UInt
    let dark: UInt

    /// A token that reads the same in both renditions — used by the flap modules,
    /// which are dark hardware whether the hall around them is lit or not.
    init(_ both: UInt) { self.light = both; self.dark = both }
    init(light: UInt, dark: UInt) { self.light = light; self.dark = dark }

    var uiColor: UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) }
    }
    var color: Color { Color(uiColor: uiColor) }
}

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Palette

/// A complete named color scheme for the Concourse Board world — a Solari rail
/// departure board rendered as a woodworking record.
///
/// Values are normative and come from `DESIGN.md` in the web repo. Light is the
/// lit concourse; dark is the board's own night form, *not* an inversion —
/// steel lifts rather than darkens and the signal lamps brighten, because that
/// is what a real board does when the hall lights go down.
struct Palette: Identifiable, Equatable {
    let id: String
    let name: String

    // Surfaces
    let concourse: WSColor   // app background — the hall
    let flapShade: WSColor   // recessed / secondary background
    let flap: WSColor        // cards — the flap face at rest

    // Text
    let ink: WSColor         // headings and board lettering
    let muted: WSColor       // muted / secondary

    // Structure
    let line: WSColor
    let steel: WSColor       // frames, header bands
    let steelDark: WSColor
    let steelLight: WSColor
    let onSteel: WSColor     // lettering on a steel band

    // Signal lamp (the user-swappable axis)
    let accent: WSColor      // legible ink weight of the lamp
    let accentDeep: WSColor
    let accentFill: WSColor  // the lamp glass itself — saturated, for fills

    // Semantic signals (shared across lamps)
    let green: WSColor
    let greenFill: WSColor
    let red: WSColor
    let redFill: WSColor

    /// Flap module internals. Deliberately identical in both renditions — this is
    /// the single detail that makes the board read as hardware rather than as a
    /// color scheme.
    let flapFace = WSColor(0x2E363B)
    let flapFaceLo = WSColor(0x232A2E)
    let flapLetter = WSColor(0xF2F4F1)

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.id == rhs.id }
}

// MARK: - Palette catalog

extension Palette {
    /// Shared board surfaces plus one signal-lamp triple. The five presets below
    /// differ only in which lamp is lit.
    private static func board(
        id: String, name: String,
        accent: WSColor, accentDeep: WSColor, accentFill: WSColor
    ) -> Palette {
        Palette(
            id: id, name: name,
            concourse: WSColor(light: 0xDDE3E0, dark: 0x0C0F10),
            flapShade: WSColor(light: 0xE5EAE6, dark: 0x101415),
            flap:      WSColor(light: 0xF7F9F6, dark: 0x171B1D),
            ink:       WSColor(light: 0x14181A, dark: 0xEFF2ED),
            muted:     WSColor(light: 0x59686A, dark: 0x8B9794),
            line:       WSColor(light: 0xC0CAC6, dark: 0x2C3335),
            steel:      WSColor(light: 0x2B3238, dark: 0x39434A),
            steelDark:  WSColor(light: 0x1A2025, dark: 0x232B30),
            steelLight: WSColor(light: 0x47535B, dark: 0x566269),
            onSteel:    WSColor(0xEDF1EE),
            accent: accent, accentDeep: accentDeep, accentFill: accentFill,
            green:     WSColor(light: 0x2E7148, dark: 0x6BC48D),
            greenFill: WSColor(0x46A46A),
            red:       WSColor(light: 0xB3271F, dark: 0xF0736A),
            redFill:   WSColor(0xD3392F)
        )
    }

    /// The default — the departure-board amber every Solari split-flap is lit in.
    static let amber = board(
        id: "amber", name: "Amber",
        accent:     WSColor(light: 0x8A4F00, dark: 0xFFB400),
        accentDeep: WSColor(0xC77800),
        accentFill: WSColor(0xFFB400)
    )
    /// Signal red — the "cancelled" lamp, borrowed as a lead.
    static let signal = board(
        id: "signal", name: "Signal",
        accent:     WSColor(light: 0xB3271F, dark: 0xF0736A),
        accentDeep: WSColor(0x8E1D17),
        accentFill: WSColor(0xD3392F)
    )
    /// Platform green — the "on time" lamp.
    static let platform = board(
        id: "platform", name: "Platform",
        accent:     WSColor(light: 0x2E7148, dark: 0x6BC48D),
        accentDeep: WSColor(0x1F5233),
        accentFill: WSColor(0x46A46A)
    )
    /// Beacon blue — the approach light.
    static let beacon = board(
        id: "beacon", name: "Beacon",
        accent:     WSColor(light: 0x1B5E8A, dark: 0x5FB5E6),
        accentDeep: WSColor(0x134563),
        accentFill: WSColor(0x2E90C7)
    )
    /// Violet — the night indicator.
    static let violet = board(
        id: "violet", name: "Violet",
        accent:     WSColor(light: 0x5B3E9B, dark: 0xA98BE6),
        accentDeep: WSColor(0x452D78),
        accentFill: WSColor(0x7C5BC4)
    )

    /// Every selectable lamp, in display order (matches the web's ACCENT_PRESETS).
    static let all: [Palette] = [.amber, .signal, .platform, .beacon, .violet]
}

// MARK: - Theme manager

/// Owns the active lamp selection, persists it, and re-styles the UIKit
/// nav/tab bars whenever it changes. Views observe this to re-render on switch.
/// (Light/dark *mode* is a separate axis — `WSColor` follows the system scheme,
/// and the app's appearance override lives in RootView.)
final class ThemeManager: ObservableObject {
    /// Only ever touched on the main thread (SwiftUI UI + appearance proxies).
    nonisolated(unsafe) static let shared = ThemeManager()
    private static let key = "ws.accent"

    @Published var selection: String {
        didSet {
            guard oldValue != selection else { return }
            UserDefaults.standard.set(selection, forKey: Self.key)
            // `selection` is only ever set from SwiftUI (main thread); re-style the
            // UIKit appearance proxies on the main actor.
            MainActor.assumeIsolated { Theme.configureAppearance() }
        }
    }

    var palette: Palette {
        Palette.all.first { $0.id == selection } ?? .amber
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key)
        // Retired names from the pre-board palette (rust/forest/slate/navy) fall
        // back rather than persisting a selection that no longer resolves.
        selection = Palette.all.first { $0.id == stored }?.id ?? Palette.amber.id
    }
}

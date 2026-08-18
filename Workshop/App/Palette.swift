import SwiftUI
import UIKit

// MARK: - Adaptive token

/// A single design token carrying a light + dark hex value. Resolves to an
/// adaptive `Color`/`UIColor` that follows the active `colorScheme`.
struct WSColor {
    let light: UInt
    let dark: UInt

    /// A token that reads the same in both renditions.
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

/// A complete adaptive palette for the Living Plan Table world. The field names
/// remain source-compatible with existing views while their roles now describe
/// vellum, glass, ink, and annotation layers rather than board hardware.
struct Palette: Identifiable, Equatable {
    let id: String
    let name: String

    // Surfaces
    let concourse: WSColor   // app background — the plan canvas
    let flapShade: WSColor   // recessed / secondary layer
    let flap: WSColor        // glass fallback / raised layer

    // Text
    let ink: WSColor         // primary text and drawing ink
    let muted: WSColor       // muted / secondary

    // Structure
    let line: WSColor
    let steel: WSColor       // sidebar / navigation material tint
    let steelDark: WSColor
    let steelLight: WSColor
    let onSteel: WSColor     // text over navigation material

    // Annotation color (the user-swappable axis)
    let accent: WSColor      // legible annotation ink
    let accentDeep: WSColor
    let accentFill: WSColor  // saturated control fill

    // Semantic signals (shared across lamps)
    let green: WSColor
    let greenFill: WSColor
    let red: WSColor
    let redFill: WSColor

    /// Compatibility tokens used by the legacy animated metric component.
    let flapFace = WSColor(light: 0xF7FAF9, dark: 0x1A2B26)
    let flapFaceLo = WSColor(light: 0xE5EFEC, dark: 0x12201D)
    let flapLetter = WSColor(light: 0x15332E, dark: 0xF2F8F6)

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.id == rhs.id }
}

// MARK: - Palette catalog

extension Palette {
    /// Shared plan-table surfaces plus one annotation triple. Preset ids stay
    /// stable so an existing selection migrates without resetting preferences.
    private static func plan(
        id: String, name: String,
        accent: WSColor, accentDeep: WSColor, accentFill: WSColor
    ) -> Palette {
        Palette(
            id: id, name: name,
            concourse: WSColor(light: 0xEEF4F2, dark: 0x0C1513),
            flapShade: WSColor(light: 0xE0EBE7, dark: 0x12201D),
            flap:      WSColor(light: 0xFAFCFB, dark: 0x182823),
            ink:       WSColor(light: 0x15332E, dark: 0xF3F8F6),
            muted:     WSColor(light: 0x58716B, dark: 0x9CB2AC),
            line:       WSColor(light: 0xC9DAD5, dark: 0x2A423C),
            steel:      WSColor(light: 0xE7F0ED, dark: 0x172923),
            steelDark:  WSColor(light: 0x15332E, dark: 0x09110F),
            steelLight: WSColor(light: 0xFFFFFF, dark: 0x254039),
            onSteel:    WSColor(light: 0x15332E, dark: 0xF3F8F6),
            accent: accent, accentDeep: accentDeep, accentFill: accentFill,
            green:     WSColor(light: 0x2F7657, dark: 0x76CFA5),
            greenFill: WSColor(light: 0x3F936D, dark: 0x4DAE81),
            red:       WSColor(light: 0xA64139, dark: 0xF28A80),
            redFill:   WSColor(light: 0xC75A50, dark: 0xD86C62)
        )
    }

    /// Default annotation: the deep spruce ink from the approved direction.
    static let amber = plan(
        id: "amber", name: "Spruce",
        accent:     WSColor(light: 0x176B5B, dark: 0x68C7B0),
        accentDeep: WSColor(light: 0x125447, dark: 0x8AD8C5),
        accentFill: WSColor(light: 0x1E7666, dark: 0x2A927E)
    )
    static let signal = plan(
        id: "signal", name: "Clay",
        accent:     WSColor(light: 0x96513E, dark: 0xE9A08A),
        accentDeep: WSColor(light: 0x743D2F, dark: 0xF0B6A5),
        accentFill: WSColor(light: 0xA95F49, dark: 0xC97C65)
    )
    static let platform = plan(
        id: "platform", name: "Moss",
        accent:     WSColor(light: 0x557A43, dark: 0x9BCB82),
        accentDeep: WSColor(light: 0x3F5E32, dark: 0xB5DEA0),
        accentFill: WSColor(light: 0x668E50, dark: 0x79A962)
    )
    static let beacon = plan(
        id: "beacon", name: "Pencil Blue",
        accent:     WSColor(light: 0x356D85, dark: 0x7AB9D3),
        accentDeep: WSColor(light: 0x29566A, dark: 0xA0D0E2),
        accentFill: WSColor(light: 0x477F97, dark: 0x5B9DB8)
    )
    static let violet = plan(
        id: "violet", name: "Iris",
        accent:     WSColor(light: 0x66568E, dark: 0xB5A4DE),
        accentDeep: WSColor(light: 0x4D416D, dark: 0xCFC3EB),
        accentFill: WSColor(light: 0x7868A2, dark: 0x9281BD)
    )

    /// Every selectable annotation color, in display order.
    static let all: [Palette] = [.amber, .signal, .platform, .beacon, .violet]
}

// MARK: - Theme manager

/// Owns the active annotation selection, persists it, and re-styles the UIKit
/// nav/tab bars whenever it changes. Views observe this to re-render on switch.
/// (Light/dark mode is a separate axis — `WSColor` follows the system scheme,
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
        // Unknown or retired ids fall back rather than persisting a selection
        // that no longer resolves.
        selection = Palette.all.first { $0.id == stored }?.id ?? Palette.amber.id
    }
}

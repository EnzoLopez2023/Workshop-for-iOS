import SwiftUI
import UIKit

// MARK: - Adaptive token

/// A single design token carrying a light + dark hex value. Resolves to an
/// adaptive `Color`/`UIColor` that follows the active `colorScheme`.
struct WSColor {
    let light: UInt
    let dark: UInt

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

/// A complete named color scheme. Every token maps 1:1 to the `Theme.*`
/// accessors, so swapping the palette re-skins everything. Workshop's web app
/// keeps the cream/ink/paper surfaces constant and varies only the *accent*
/// across 5 presets — so all palettes here share surfaces and differ in accent.
struct Palette: Identifiable, Equatable {
    let id: String
    let name: String

    // Surfaces
    let cream: WSColor       // app background
    let creamSoft: WSColor   // secondary background (cream-2)
    let paper: WSColor       // cards

    // Text
    let ink: WSColor         // headings
    let inkSoft: WSColor     // body
    let subtle: WSColor      // muted / secondary

    // Lines + accent
    let line: WSColor
    let lineStrong: WSColor
    let accent: WSColor
    let accentDeep: WSColor
    let accentSoft: WSColor

    // Semantic status (shared across accents)
    let excellent: WSColor
    let good: WSColor
    let amber: WSColor
    let emerald: WSColor
    let fail: WSColor

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.id == rhs.id }
}

// MARK: - Palette catalog

extension Palette {
    /// Shared Workshop surfaces (from `src/index.css` `:root` + `[data-theme=dark]`)
    /// plus one accent triple. The 5 presets below differ only in accent.
    private static func workshop(
        id: String, name: String,
        accent: WSColor, accentDeep: WSColor, accentSoft: WSColor
    ) -> Palette {
        Palette(
            id: id, name: name,
            cream:     WSColor(light: 0xF5F0EA, dark: 0x171009),
            creamSoft: WSColor(light: 0xEFE8DF, dark: 0x1F1510),
            paper:     WSColor(light: 0xFFFFFF, dark: 0x261A12),
            ink:       WSColor(light: 0x1C0F07, dark: 0xEFE4D6),
            inkSoft:   WSColor(light: 0x3D2817, dark: 0xB07840),
            subtle:    WSColor(light: 0x8B7A6B, dark: 0x8A7565),
            line:       WSColor(light: 0xEDE8E3, dark: 0x3A2A1E),
            lineStrong: WSColor(light: 0xD9CFC4, dark: 0x55402F),
            accent: accent, accentDeep: accentDeep, accentSoft: accentSoft,
            excellent: WSColor(light: 0x166534, dark: 0x6EE7B7),
            good:      WSColor(light: 0x1E40AF, dark: 0x93C5FD),
            amber:     WSColor(light: 0xD97706, dark: 0xFCD34D),
            emerald:   WSColor(light: 0x10B981, dark: 0x34D399),
            fail:      WSColor(light: 0xB1442E, dark: 0xE08060)
        )
    }

    /// The default — rust over cream, carried from the web app (`--color-rust`).
    static let rust = workshop(
        id: "rust", name: "Rust",
        accent:     WSColor(light: 0xA0522D, dark: 0xC87040),
        accentDeep: WSColor(light: 0x7C3E1F, dark: 0xA85C2A),
        accentSoft: WSColor(light: 0xFBEFE4, dark: 0x2D1A08)
    )
    static let forest = workshop(
        id: "forest", name: "Forest",
        accent:     WSColor(light: 0x2E7D52, dark: 0x4AA574),
        accentDeep: WSColor(light: 0x1E5C3A, dark: 0x2E7D52),
        accentSoft: WSColor(light: 0xE8F3ED, dark: 0x0E241A)
    )
    static let slate = workshop(
        id: "slate", name: "Slate",
        accent:     WSColor(light: 0x5B6AA7, dark: 0x7C8AC4),
        accentDeep: WSColor(light: 0x404E8A, dark: 0x5B6AA7),
        accentSoft: WSColor(light: 0xEDEFF7, dark: 0x171B2E)
    )
    static let amber = workshop(
        id: "amber", name: "Amber",
        accent:     WSColor(light: 0xB07A2A, dark: 0xD49A3E),
        accentDeep: WSColor(light: 0x8A5F1C, dark: 0xB07A2A),
        accentSoft: WSColor(light: 0xF7EFE0, dark: 0x2A1E0C)
    )
    static let navy = workshop(
        id: "navy", name: "Navy",
        accent:     WSColor(light: 0x2A4B7C, dark: 0x4A6DA0),
        accentDeep: WSColor(light: 0x1E3860, dark: 0x2A4B7C),
        accentSoft: WSColor(light: 0xE6ECF5, dark: 0x0E1A2E)
    )

    /// Every selectable accent, in display order (matches the web's ACCENT_PRESETS).
    static let all: [Palette] = [.rust, .forest, .slate, .amber, .navy]
}

// MARK: - Theme manager

/// Owns the active accent selection, persists it, and re-styles the UIKit
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
        Palette.all.first { $0.id == selection } ?? .rust
    }

    private init() {
        selection = UserDefaults.standard.string(forKey: Self.key) ?? Palette.rust.id
    }
}

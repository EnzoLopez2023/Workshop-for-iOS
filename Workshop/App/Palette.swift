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
    init(_ value: AdaptiveRGB) { self.init(light: value.light, dark: value.dark) }

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

/// A complete adaptive palette for the Living Plan Table world.
struct Palette: Identifiable, Equatable {
    let id: String
    let name: String

    // Surfaces
    let canvas: WSColor
    let recessed: WSColor
    let raised: WSColor

    // Text
    let ink: WSColor
    let muted: WSColor

    // Structure
    let divider: WSColor
    let navigationMaterial: WSColor
    let navigationDeep: WSColor
    let navigationHighlight: WSColor
    let onNavigation: WSColor

    // Annotation color (the user-swappable axis)
    let annotation: WSColor
    let action: WSColor
    let annotationFill: WSColor

    // Semantic signals
    let success: WSColor
    let successFill: WSColor
    let danger: WSColor
    let dangerFill: WSColor

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.id == rhs.id }
}

// MARK: - Palette catalog

extension Palette {
    /// Shared plan-table surfaces plus one annotation triple. Preset ids stay
    /// stable so an existing selection migrates without resetting preferences.
    private static func plan(
        id: String, name: String,
        annotation: AdaptiveRGB, action: AdaptiveRGB, annotationFill: AdaptiveRGB
    ) -> Palette {
        Palette(
            id: id, name: name,
            canvas: WSColor(LivingPlanTokens.canvas),
            recessed: WSColor(LivingPlanTokens.recessed),
            raised: WSColor(LivingPlanTokens.raised),
            ink: WSColor(LivingPlanTokens.ink),
            muted: WSColor(LivingPlanTokens.mutedInk),
            divider: WSColor(LivingPlanTokens.divider),
            navigationMaterial: WSColor(LivingPlanTokens.navigationMaterial),
            navigationDeep: WSColor(LivingPlanTokens.navigationDeep),
            navigationHighlight: WSColor(LivingPlanTokens.navigationHighlight),
            onNavigation: WSColor(LivingPlanTokens.onNavigation),
            annotation: WSColor(annotation),
            action: WSColor(action),
            annotationFill: WSColor(annotationFill),
            success: WSColor(LivingPlanTokens.success),
            successFill: WSColor(LivingPlanTokens.successFill),
            danger: WSColor(LivingPlanTokens.danger),
            dangerFill: WSColor(LivingPlanTokens.dangerFill)
        )
    }

    /// Default annotation: the deep spruce ink from the approved direction.
    static let spruce = plan(
        id: "amber", name: "Spruce",
        annotation: LivingPlanTokens.spruceAnnotation,
        action: LivingPlanTokens.spruceAction,
        annotationFill: LivingPlanTokens.spruceFill
    )
    static let clay = plan(
        id: "signal", name: "Clay",
        annotation: LivingPlanTokens.clayAnnotation,
        action: LivingPlanTokens.clayAction,
        annotationFill: LivingPlanTokens.clayFill
    )
    static let moss = plan(
        id: "platform", name: "Moss",
        annotation: LivingPlanTokens.mossAnnotation,
        action: LivingPlanTokens.mossAction,
        annotationFill: LivingPlanTokens.mossFill
    )
    static let pencilBlue = plan(
        id: "beacon", name: "Pencil Blue",
        annotation: LivingPlanTokens.pencilBlueAnnotation,
        action: LivingPlanTokens.pencilBlueAction,
        annotationFill: LivingPlanTokens.pencilBlueFill
    )
    static let iris = plan(
        id: "violet", name: "Iris",
        annotation: LivingPlanTokens.irisAnnotation,
        action: LivingPlanTokens.irisAction,
        annotationFill: LivingPlanTokens.irisFill
    )

    /// Every selectable annotation color, in display order.
    static let all: [Palette] = [.spruce, .clay, .moss, .pencilBlue, .iris]
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
        Palette.all.first { $0.id == selection } ?? .spruce
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key)
        // Unknown or retired ids fall back rather than persisting a selection
        // that no longer resolves.
        selection = Palette.all.first { $0.id == stored }?.id ?? Palette.spruce.id
    }
}

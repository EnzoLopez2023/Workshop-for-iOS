import SwiftUI
import NintekKit

/// Pill badge for a project status — mirrors the web `StatusBadge` colors
/// (`src/components/StatusBadge.tsx`), with dark-mode variants derived from the
/// same hues. `withBackdrop` is the translucent style used over a hero image.
struct StatusBadge: View {
    let status: ProjectStatus
    var withBackdrop = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(colors.dot.color).frame(width: 6, height: 6)
            Text(status.label)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(background, in: Capsule())
        .foregroundStyle(colors.fg.color)
    }

    private var background: some ShapeStyle {
        withBackdrop ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(colors.bg.color)
    }

    private var colors: (bg: WSColor, fg: WSColor, dot: WSColor) {
        switch status {
        case .idea:
            return (WSColor(light: 0xF8E7DC, dark: 0x3A2A1E), WSColor(light: 0xB06B3F, dark: 0xD9A06E), WSColor(light: 0xC77C4A, dark: 0xC77C4A))
        case .planning:
            return (WSColor(light: 0xE8EBF5, dark: 0x23283A), WSColor(light: 0x5B6AA7, dark: 0x9AA6D8), WSColor(light: 0x7A88C4, dark: 0x7A88C4))
        case .inProgress:
            return (WSColor(light: 0xFCEBDA, dark: 0x3A2A18), WSColor(light: 0xB96F1F, dark: 0xE0A05A), WSColor(light: 0xD6842E, dark: 0xD6842E))
        case .completed:
            return (WSColor(light: 0xE6EFE2, dark: 0x1E2A1C), WSColor(light: 0x4F7A3E, dark: 0x8FBF77), WSColor(light: 0x6FA057, dark: 0x6FA057))
        case .unknown:
            return (WSColor(light: 0xEDE8E3, dark: 0x3A2A1E), WSColor(light: 0x8B7A6B, dark: 0xB39A86), WSColor(light: 0x8B7A6B, dark: 0xB39A86))
        }
    }
}

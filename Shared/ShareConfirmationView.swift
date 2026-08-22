import SwiftUI
import UIKit

/// The default Spruce rendition used by processes that cannot observe the
/// app's user-selected annotation color.
private enum ShareTheme {
    static let raised = adaptive(LivingPlanTokens.raised)
    static let ink = adaptive(LivingPlanTokens.ink)
    static let muted = adaptive(LivingPlanTokens.mutedInk)
    static let divider = adaptive(LivingPlanTokens.divider)
    static let action = adaptive(LivingPlanTokens.spruceAction)
    static let successFill = adaptive(LivingPlanTokens.successFill)
    static let dangerFill = adaptive(LivingPlanTokens.dangerFill)
    static let navigationDeep = adaptive(LivingPlanTokens.navigationDeep)
    static let onSemanticFill = Color(uiColor: UIColor {
        $0.userInterfaceStyle == .dark ? ui(LivingPlanTokens.navigationDeep.dark) : .white
    })

    static func adaptive(_ value: AdaptiveRGB) -> Color {
        Color(uiColor: UIColor {
            $0.userInterfaceStyle == .dark ? ui(value.dark) : ui(value.light)
        })
    }

    private static func ui(_ hex: UInt) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct ShareConfirmationView: View {
    let message: String
    let ok: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 9) {
                    Image(systemName: "hammer.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(ShareTheme.action)
                    Text("Workshop")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(ShareTheme.ink)
                    Spacer(minLength: 0)
                    Image(systemName: ok ? "checkmark" : "exclamationmark")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(ShareTheme.onSemanticFill)
                        .frame(width: 36, height: 36)
                        .background(
                            ok ? ShareTheme.successFill : ShareTheme.dangerFill,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityHidden(true)
                }

                Rectangle()
                    .fill(ShareTheme.divider.opacity(0.72))
                    .frame(height: 1)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text(ok ? "Saved to Workshop" : "Couldn’t Save")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(ShareTheme.ink)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(ShareTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: 420, alignment: .leading)
            .background(
                reduceTransparency ? AnyShapeStyle(ShareTheme.raised) : AnyShapeStyle(.ultraThinMaterial),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ShareTheme.divider.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: ShareTheme.navigationDeep.opacity(0.16), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("share-confirmation")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ok ? "Saved to Workshop" : "Couldn’t save"). \(message)")
    }
}

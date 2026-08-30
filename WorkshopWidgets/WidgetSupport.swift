import SwiftUI
import WidgetKit
import NintekKit

// MARK: - Palette

/// Living Plan Table, hardcoded for the widget process. The extension
/// can't reach the app's `ThemeManager` (palettes live in the app target and are
/// user-selectable at runtime), so widgets use the default spruce annotation.
enum WSWidget {
    static let canvas = wsAdaptive(LivingPlanTokens.canvas)
    static let raised = wsAdaptive(LivingPlanTokens.raised)
    static let recessed = wsAdaptive(LivingPlanTokens.recessed)
    static let ink = wsAdaptive(LivingPlanTokens.ink)
    static let muted = wsAdaptive(LivingPlanTokens.mutedInk)
    static let divider = wsAdaptive(LivingPlanTokens.divider)
    static let navigationMaterial = wsAdaptive(LivingPlanTokens.navigationMaterial)

    static let annotation = wsAdaptive(LivingPlanTokens.spruceAnnotation)
    static let annotationFill = wsAdaptive(LivingPlanTokens.spruceFill)
    static let success = wsAdaptive(LivingPlanTokens.success)
    static let danger = wsAdaptive(LivingPlanTokens.danger)

    static let rCompact: CGFloat = 10
    static let rPanel: CGFloat = 14

    /// SF Rounded for compact labels and data.
    static func rounded(_ size: CGFloat, _ weight: RoundedWeight = .regular) -> Font {
        .system(size: size, weight: weight.fontWeight, design: .rounded)
    }
    /// SF Pro for body copy.
    static func ui(_ size: CGFloat, _ weight: UIWeight = .regular) -> Font {
        .system(size: size, weight: weight.fontWeight)
    }

    enum RoundedWeight {
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

    /// Compact whole-dollar currency (e.g. "$1.2k" for tiles).
    static func currency(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "$%.1fk", v / 1000)
        }
        let f = NumberFormatter(); f.numberStyle = .currency; f.maximumFractionDigits = 0
        return f.string(from: v as NSNumber) ?? "$0"
    }
}

/// A light/dark pair resolved through the active trait collection — the widget's
/// stand-in for the app's `WSColor`.
func wsAdaptive(_ value: AdaptiveRGB) -> Color {
    Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(wsHex: value.dark) : UIColor(wsHex: value.light) })
}

extension UIColor {
    convenience init(wsHex: UInt) {
        self.init(red: CGFloat((wsHex >> 16) & 0xFF) / 255,
                  green: CGFloat((wsHex >> 8) & 0xFF) / 255,
                  blue: CGFloat(wsHex & 0xFF) / 255, alpha: 1)
    }
}

/// Compact semantic label.
struct WSLabel: View {
    let text: String
    var size: CGFloat = 9.5
    var color: Color = WSWidget.muted
    init(_ text: String, size: CGFloat = 9.5, color: Color = WSWidget.muted) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text)
            .font(WSWidget.rounded(size, .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// A compact tabular metric.
struct WSMetric: View {
    let value: String
    var size: CGFloat = 15
    var tone: Color = WSWidget.ink
    var body: some View {
        Text(value)
            .font(WSWidget.rounded(size, .bold))
            .foregroundStyle(tone)
            .monospacedDigit()
    }
}

/// Left-pads with zeros so a figure always fills its cells.
func wsPad(_ n: Int, _ width: Int = 2) -> String {
    String(format: "%0\(width)d", n)
}

// MARK: - Deep links

/// The `workshop://` links the widgets open. Handled by `AppModel.handleDeepLink`.
enum WSDeepLink {
    static let dashboard = URL(string: "workshop://dashboard")!
    static func project(_ id: Int) -> URL { URL(string: "workshop://project/\(id)")! }
}

// MARK: - Timeline

/// One timeline entry — just the shared snapshot at a point in time.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WorkshopWidgetSnapshot
}

/// Reads the App-Group snapshot the app publishes. No network / auth here — the
/// app owns that and writes the snapshot, so the widget stays reliable. We ask
/// WidgetKit to refresh periodically as a backstop; the app also nudges a reload
/// (`WidgetCenter.reloadAllTimelines`) whenever it writes fresh data.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .sample : (WorkshopWidgetStore.load() ?? .sample)
        completion(SnapshotEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WorkshopWidgetStore.load() ?? .signedOut
        let entry = SnapshotEntry(date: Date(), snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Shared bits

/// A "sign in to Workshop" prompt shown when no session snapshot exists.
struct SignedOutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WSWidget.annotation)
            WSLabel("Sign in to Workshop", size: 9)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Plan-layer header shared by every widget.
struct WSHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 8))
                .foregroundStyle(WSWidget.annotationFill)
            WSLabel(title, size: 9, color: WSWidget.ink)
            Spacer(minLength: 4)
            if let trailing {
                WSLabel(trailing, size: 8, color: WSWidget.annotation)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(WSWidget.navigationMaterial.opacity(0.86))
        .overlay(alignment: .bottom) {
            Rectangle().fill(WSWidget.divider.opacity(0.7)).frame(height: 0.5)
        }
    }
}

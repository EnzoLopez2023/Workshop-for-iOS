import SwiftUI
import WidgetKit
import NintekKit

// MARK: - Palette

/// Living Plan Table, hardcoded for the widget process. The extension
/// can't reach the app's `ThemeManager` (palettes live in the app target and are
/// user-selectable at runtime), so widgets use the default spruce annotation.
enum WSWidget {
    static let concourse = wsAdaptive(0xEEF4F2, 0x0C1513)
    static let flap      = wsAdaptive(0xFAFCFB, 0x182823)
    static let flapShade = wsAdaptive(0xE0EBE7, 0x12201D)
    static let ink       = wsAdaptive(0x15332E, 0xF3F8F6)
    static let subtle    = wsAdaptive(0x58716B, 0x9CB2AC)
    static let line      = wsAdaptive(0xC9DAD5, 0x2A423C)
    static let steel     = wsAdaptive(0xE7F0ED, 0x172923)
    static let onSteel   = wsAdaptive(0x15332E, 0xF3F8F6)

    static let accent     = wsAdaptive(0x176B5B, 0x68C7B0)
    static let accentFill = wsAdaptive(0x1E7666, 0x2A927E)
    static let green      = wsAdaptive(0x2F7657, 0x76CFA5)
    static let red        = wsAdaptive(0xA64139, 0xF28A80)

    static let flapFace   = wsAdaptive(0xF7FAF9, 0x1A2B26)
    static let flapFaceLo = wsAdaptive(0xE5EFEC, 0x12201D)
    static let flapLetter = wsAdaptive(0x15332E, 0xF2F8F6)

    static let rFlap: CGFloat = 10
    static let rPanel: CGFloat = 14

    /// SF Rounded for compact labels and data.
    static func board(_ size: CGFloat, _ weight: BoardWeight = .regular) -> Font {
        .system(size: size, weight: weight.fontWeight, design: .rounded)
    }
    /// SF Pro for body copy.
    static func ui(_ size: CGFloat, _ weight: UIWeight = .regular) -> Font {
        .system(size: size, weight: weight.fontWeight)
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
func wsAdaptive(_ light: UInt, _ dark: UInt) -> Color {
    Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(wsHex: dark) : UIColor(wsHex: light) })
}

extension UIColor {
    convenience init(wsHex: UInt) {
        self.init(red: CGFloat((wsHex >> 16) & 0xFF) / 255,
                  green: CGFloat((wsHex >> 8) & 0xFF) / 255,
                  blue: CGFloat(wsHex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// Build a Color from a 0xRRGGBB literal (parity with the app's Palette).
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Compact semantic label.
struct WSCaps: View {
    let text: String
    var size: CGFloat = 9.5
    var color: Color = WSWidget.subtle
    init(_ text: String, size: CGFloat = 9.5, color: Color = WSWidget.subtle) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text)
            .font(WSWidget.board(size, .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// Source-compatible single character without the retired split-flap hardware.
struct WSFlap: View {
    let char: String
    var size: CGFloat = 15
    var tone: Color = WSWidget.flapLetter
    var body: some View {
        Text(char)
            .font(WSWidget.board(size, .bold))
            .foregroundStyle(tone)
            .monospacedDigit()
    }
}

/// A compact tabular metric.
struct WSFlapNumber: View {
    let value: String
    var size: CGFloat = 15
    var tone: Color = WSWidget.flapLetter
    var body: some View {
        Text(value)
            .font(WSWidget.board(size, .bold))
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

/// A "sign in to Workshop" prompt shown when no session snapshot exists — the
/// board with nothing scheduled on it.
struct SignedOutView: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { _ in
                    WSFlap(char: "-", size: 13, tone: WSWidget.flapLetter.opacity(0.45))
                }
            }
            WSCaps("Sign in to Workshop", size: 9)
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
                .foregroundStyle(WSWidget.accentFill)
            WSCaps(title, size: 9, color: WSWidget.ink)
            Spacer(minLength: 4)
            if let trailing {
                WSCaps(trailing, size: 8, color: WSWidget.accent)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(WSWidget.steel.opacity(0.86))
        .overlay(alignment: .bottom) {
            Rectangle().fill(WSWidget.line.opacity(0.7)).frame(height: 0.5)
        }
    }
}

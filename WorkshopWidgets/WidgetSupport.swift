import SwiftUI
import WidgetKit
import NintekKit

// MARK: - Palette

/// The Concourse Board world, hardcoded for the widget process. The extension
/// can't reach the app's `ThemeManager` (palettes live in the app target and are
/// user-selectable at runtime), so the widget always ships the default amber
/// lamp. Values mirror `Palette.amber` — see DESIGN.md.
enum WSWidget {
    static let concourse = wsAdaptive(0xDDE3E0, 0x0C0F10)  // the hall
    static let flap      = wsAdaptive(0xF7F9F6, 0x171B1D)  // a flap face at rest
    static let flapShade = wsAdaptive(0xE5EAE6, 0x101415)  // recessed
    static let ink       = wsAdaptive(0x14181A, 0xEFF2ED)
    static let subtle    = wsAdaptive(0x59686A, 0x8B9794)
    static let line      = wsAdaptive(0xC0CAC6, 0x2C3335)
    /// Steel lifts in the dark rendition rather than darkening — a real board
    /// does the same when the hall lights go down.
    static let steel     = wsAdaptive(0x2B3238, 0x39434A)
    static let onSteel   = wsAdaptive(0xEDF1EE, 0xEDF1EE)

    static let accent    = wsAdaptive(0x8A4F00, 0xFFB400)  // amber ink
    static let accentFill = wsAdaptive(0xFFB400, 0xFFB400) // the lamp glass
    static let green     = wsAdaptive(0x2E7148, 0x46A46A)
    static let red       = wsAdaptive(0xB3271F, 0xD3392F)

    /// Flap modules are dark hardware in both renditions.
    static let flapFace   = Color(hex: 0x2E363B)
    static let flapFaceLo = Color(hex: 0x232A2E)
    static let flapLetter = Color(hex: 0xF2F4F1)

    static let rFlap: CGFloat = 2
    static let rPanel: CGFloat = 3

    /// Martian Mono, condensed — board caps and every datum.
    static func board(_ size: CGFloat, _ weight: BoardWeight = .regular) -> Font {
        .custom(weight.psName, size: size)
    }
    /// Archivo — UI labels and body copy.
    static func ui(_ size: CGFloat, _ weight: UIWeight = .regular) -> Font {
        .custom(weight.psName, size: size)
    }

    enum BoardWeight {
        case regular, semibold, bold
        var psName: String {
            switch self {
            case .regular:  "MartianMonoBoard-Regular"
            case .semibold: "MartianMonoBoard-SemiBold"
            case .bold:     "MartianMonoBoard-Bold"
            }
        }
    }
    enum UIWeight {
        case regular, medium, bold
        var psName: String {
            switch self {
            case .regular: "ArchivoWS-Regular"
            case .medium:  "ArchivoWS-Medium"
            case .bold:    "ArchivoWS-Bold"
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

/// Tracked caps on the board's own face — the widget's structural label.
struct WSCaps: View {
    let text: String
    var size: CGFloat = 9.5
    var color: Color = WSWidget.subtle
    init(_ text: String, size: CGFloat = 9.5, color: Color = WSWidget.subtle) {
        self.text = text; self.size = size; self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(WSWidget.board(size, .semibold))
            .tracking(1.0)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// A single flap module carrying one character. Static here — a widget gets no
/// animation budget, and the board has to read as a board at rest anyway.
struct WSFlap: View {
    let char: String
    var size: CGFloat = 15
    var tone: Color = WSWidget.flapLetter
    var body: some View {
        Text(char)
            .font(WSWidget.board(size, .bold))
            .foregroundStyle(tone)
            .frame(width: size * 0.86, height: size * 1.5)
            .background(
                LinearGradient(colors: [WSWidget.flapFace, WSWidget.flapFaceLo],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(Rectangle().fill(.black.opacity(0.55)).frame(height: 1))
            .clipShape(RoundedRectangle(cornerRadius: WSWidget.rFlap))
    }
}

/// A number rendered as a row of flap modules, zero-padded so no cell reads dead.
struct WSFlapNumber: View {
    let value: String
    var size: CGFloat = 15
    var tone: Color = WSWidget.flapLetter
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(value.enumerated()), id: \.offset) { _, c in
                WSFlap(char: String(c), size: size, tone: tone)
            }
        }
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

/// The steel header band every widget wears — the board's frame, carried across
/// surfaces exactly as it is in the app.
struct WSHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 8))
                .foregroundStyle(WSWidget.accentFill)
            WSCaps(title, size: 9, color: WSWidget.onSteel)
            Spacer(minLength: 4)
            if let trailing {
                WSCaps(trailing, size: 8, color: WSWidget.accentFill)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x3A434A), Color(hex: 0x232A2F)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

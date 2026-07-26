import SwiftUI
import WidgetKit
import NintekKit

// MARK: - Palette

/// Workshop's warm identity, hardcoded for the widget process. The extension
/// can't reach the app's `ThemeManager` (palettes live in the app target and
/// are user-selectable at runtime), so the widget ships the default rust/cream
/// look. Colors mirror `Palette.rust`'s defaults.
enum WSWidget {
    static let accent   = Color(hex: 0xA0522D)   // rust
    static let ink      = Color(hex: 0x1C0F07)   // headings
    static let inkSoft  = Color(hex: 0x3D2817)   // body
    static let subtle   = Color(hex: 0x8B7A6B)   // muted
    static let cream    = Color(hex: 0xF5F0EA)   // widget background
    static let paper    = Color(hex: 0xFFFFFF)   // inner surface
    static let line     = Color(hex: 0xEDE8E3)

    static let amber    = Color(hex: 0xD97706)
    static let emerald  = Color(hex: 0x10B981)

    /// Compact whole-dollar currency (e.g. "$1.2k" for tiles).
    static func currency(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "$%.1fk", v / 1000)
        }
        let f = NumberFormatter(); f.numberStyle = .currency; f.maximumFractionDigits = 0
        return f.string(from: v as NSNumber) ?? "$0"
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
        VStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.title2).foregroundStyle(WSWidget.accent)
            Text("Sign in to Workshop")
                .font(.caption).foregroundStyle(WSWidget.subtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

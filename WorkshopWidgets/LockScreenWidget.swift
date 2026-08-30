import SwiftUI
import WidgetKit
import NintekKit

/// Lock Screen / StandBy widget (Phase 7.9+) — the same App-Group snapshot
/// every other widget reads, just in the three accessory families. Unlike the
/// Home Screen widgets, these render in the system's own monochrome/tinted
/// rendering intent, so they use plain SF Symbols and system text.
struct LockScreenWidget: Widget {
    let kind = "WorkshopLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            LockScreenWidgetView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Workshop Glance")
        .description("In-progress build count for your Lock Screen or StandBy.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WorkshopWidgetSnapshot

    var body: some View {
        Group {
            if !snapshot.signedIn {
                signedOut
            } else {
                switch family {
                case .accessoryCircular: circular
                case .accessoryRectangular: rectangular
                default: inline
                }
            }
        }
        .widgetURL(WSDeepLink.dashboard)
    }

    private var circular: some View {
        Gauge(value: Double(min(snapshot.inProgressCount, 5)), in: 0...5) {
            Image(systemName: "hammer.fill")
        } currentValueLabel: {
            Text("\(snapshot.inProgressCount)")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Workshop", systemImage: "hammer.fill")
                .font(.caption2.bold())
            Text("\(snapshot.inProgressCount) in progress")
                .font(.caption)
            Text("\(snapshot.inQueueCount) in queue")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var inline: some View {
        Label("\(snapshot.inProgressCount) in progress, \(snapshot.inQueueCount) in queue", systemImage: "hammer.fill")
    }

    @ViewBuilder private var signedOut: some View {
        switch family {
        case .accessoryCircular: Image(systemName: "hammer")
        case .accessoryRectangular: Label("Sign in to Workshop", systemImage: "hammer")
        default: Label("Sign in to Workshop", systemImage: "hammer")
        }
    }
}

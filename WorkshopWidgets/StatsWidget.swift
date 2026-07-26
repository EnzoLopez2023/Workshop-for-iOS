import SwiftUI
import WidgetKit
import NintekKit

/// At-a-glance project stats. Small = the two headline numbers (in-progress
/// count + parts); medium = the full four-tile row mirroring the app's
/// dashboard stat strip. Tapping deep-links into the app.
struct StatsWidget: Widget {
    let kind = "WorkshopStats"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            StatsWidgetView(snapshot: entry.snapshot)
                .containerBackground(WSWidget.cream, for: .widget)
        }
        .configurationDisplayName("Project Stats")
        .description("Your active builds, queue, parts, and materials value.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WorkshopWidgetSnapshot

    var body: some View {
        if !snapshot.signedIn {
            SignedOutView()
        } else if family == .systemSmall {
            small
        } else {
            medium
        }
    }

    // MARK: Small — headline + queue

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.caption2).foregroundStyle(WSWidget.accent)
                Text("WORKSHOP")
                    .font(.system(size: 10, weight: .bold)).tracking(1)
                    .foregroundStyle(WSWidget.subtle)
            }
            Spacer(minLength: 4)
            Text("\(snapshot.inProgressCount)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(WSWidget.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("ACTIVE BUILDS")
                .font(.system(size: 10, weight: .bold)).tracking(0.5)
                .foregroundStyle(WSWidget.subtle)
            Spacer(minLength: 6)
            queuePill
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WSDeepLink.dashboard)
    }

    private var queuePill: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.stack.3d.up.fill").font(.caption2)
            Text("\(snapshot.inQueueCount) in queue")
                .font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(WSWidget.accent)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WSWidget.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Medium — four tiles

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.caption2).foregroundStyle(WSWidget.accent)
                Text("Workshop").font(.subheadline.weight(.bold)).foregroundStyle(WSWidget.accent)
                Spacer()
                Text("Updated \(snapshot.updatedAt, style: .time)")
                    .font(.system(size: 10)).foregroundStyle(WSWidget.subtle)
            }
            HStack(spacing: 8) {
                Link(destination: WSDeepLink.dashboard) {
                    tile("hammer.fill", "\(snapshot.inProgressCount)", "In Progress", WSWidget.accent)
                }
                Link(destination: WSDeepLink.dashboard) {
                    tile("square.stack.3d.up.fill", "\(snapshot.inQueueCount)", "In Queue", WSWidget.amber)
                }
                Link(destination: WSDeepLink.dashboard) {
                    tile("square.grid.3x3.fill", "\(snapshot.totalParts)", "Parts", WSWidget.inkSoft)
                }
                Link(destination: WSDeepLink.dashboard) {
                    tile("dollarsign.circle.fill", WSWidget.currency(snapshot.totalValue), "Value", WSWidget.emerald)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func tile(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            Spacer(minLength: 0)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(WSWidget.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.4)
                .foregroundStyle(WSWidget.subtle).lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WSWidget.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(WSWidget.line, lineWidth: 1))
    }
}

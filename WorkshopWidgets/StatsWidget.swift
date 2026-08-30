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
                .containerBackground(WSWidget.raised, for: .widget)
        }
        .configurationDisplayName("Project Stats")
        .description("Your active builds, queue, parts, and materials value.")
        .contentMarginsDisabled()
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
            WSLabel("Workshop")
            Spacer(minLength: 6)
            WSMetric(value: wsPad(snapshot.inProgressCount),
                         size: 24, tone: WSWidget.annotationFill)
            Spacer(minLength: 5)
            WSLabel("Active builds", size: 9)
            Spacer(minLength: 8)
            queueRail
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WSWidget.raised)
        .widgetURL(WSDeepLink.dashboard)
    }

    /// The queue is secondary to the active-build total.
    private var queueRail: some View {
        HStack(spacing: 6) {
            WSLabel("In queue", size: 8.5)
            Spacer(minLength: 4)
            WSMetric(value: wsPad(snapshot.inQueueCount), size: 11)
        }
        .padding(.horizontal, 7).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(WSWidget.recessed)
        .overlay(RoundedRectangle(cornerRadius: WSWidget.rPanel)
            .strokeBorder(WSWidget.divider, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: WSWidget.rPanel))
    }

    // MARK: Medium

    private var medium: some View {
        VStack(spacing: 0) {
            WSHeader(title: "Workshop",
                     trailing: snapshot.updatedAt.formatted(date: .omitted, time: .shortened))
            HStack(spacing: 0) {
                Link(destination: WSDeepLink.dashboard) {
                    cell(wsPad(snapshot.inProgressCount), "In Progress", WSWidget.annotationFill)
                }
                divider
                Link(destination: WSDeepLink.dashboard) {
                    cell(wsPad(snapshot.inQueueCount), "In Queue", WSWidget.ink)
                }
                divider
                Link(destination: WSDeepLink.dashboard) {
                    cell(wsPad(snapshot.totalParts, 3), "Parts", WSWidget.ink)
                }
                divider
                Link(destination: WSDeepLink.dashboard) {
                    cell(WSWidget.currency(snapshot.totalValue), "Value", WSWidget.ink)
                }
            }
            .frame(maxHeight: .infinity)
            .background(WSWidget.raised)
        }
    }

    private var divider: some View {
        Rectangle().fill(WSWidget.divider).frame(width: 1)
    }

    /// One equal-width metric cell, sized for compact currency such as "$1.2k".
    private func cell(_ value: String, _ label: String, _ tone: Color) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            WSMetric(value: value, size: 13, tone: tone)
                .padding(.horizontal, 6)
            Spacer(minLength: 4)
            WSLabel(label, size: 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(WSWidget.recessed)
                .overlay(alignment: .top) {
                    Rectangle().fill(WSWidget.divider).frame(height: 1)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

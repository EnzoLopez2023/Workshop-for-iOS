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
                .containerBackground(WSWidget.flap, for: .widget)
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
            WSCaps("Workshop")
            Spacer(minLength: 6)
            WSFlapNumber(value: wsPad(snapshot.inProgressCount),
                         size: 24, tone: WSWidget.accentFill)
            Spacer(minLength: 5)
            WSCaps("Active builds", size: 9)
            Spacer(minLength: 8)
            queueRail
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WSWidget.flap)
        .widgetURL(WSDeepLink.dashboard)
    }

    /// The queue reads as a second board row, not a tinted pill.
    private var queueRail: some View {
        HStack(spacing: 6) {
            WSCaps("In queue", size: 8.5)
            Spacer(minLength: 4)
            WSFlapNumber(value: wsPad(snapshot.inQueueCount), size: 11)
        }
        .padding(.horizontal, 7).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(WSWidget.flapShade)
        .overlay(RoundedRectangle(cornerRadius: WSWidget.rPanel)
            .strokeBorder(WSWidget.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: WSWidget.rPanel))
    }

    // MARK: Medium — four tiles

    private var medium: some View {
        VStack(spacing: 0) {
            WSHeader(title: "Workshop",
                     trailing: snapshot.updatedAt.formatted(date: .omitted, time: .shortened))
            HStack(spacing: 0) {
                Link(destination: WSDeepLink.dashboard) {
                    cell(wsPad(snapshot.inProgressCount), "In Progress", WSWidget.accentFill)
                }
                divider
                Link(destination: WSDeepLink.dashboard) {
                    cell(wsPad(snapshot.inQueueCount), "In Queue", WSWidget.flapLetter)
                }
                divider
                Link(destination: WSDeepLink.dashboard) {
                    cell(wsPad(snapshot.totalParts, 3), "Parts", WSWidget.flapLetter)
                }
                divider
                Link(destination: WSDeepLink.dashboard) {
                    cell(WSWidget.currency(snapshot.totalValue), "Value", WSWidget.flapLetter)
                }
            }
            .frame(maxHeight: .infinity)
            .background(WSWidget.flap)
        }
    }

    private var divider: some View {
        Rectangle().fill(WSWidget.line).frame(width: 1)
    }

    /// One cell of the board: the figure on flaps, sitting on a shaded footer
    /// rail that carries the label — so the cell fills its full height the way
    /// a real board column does. Sized for the widest string this row can
    /// produce, a compact currency like "$1.2k" at five modules.
    private func cell(_ value: String, _ label: String, _ tone: Color) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)
            WSFlapNumber(value: value, size: 13, tone: tone)
                .padding(.horizontal, 6)
            Spacer(minLength: 4)
            WSCaps(label, size: 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(WSWidget.flapShade)
                .overlay(alignment: .top) {
                    Rectangle().fill(WSWidget.line).frame(height: 1)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

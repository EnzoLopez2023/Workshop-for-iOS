import SwiftUI
import WidgetKit
import NintekKit

/// A list of the projects currently "In Progress" — a home-screen mirror of
/// the app's dashboard "In Progress" filter. Each row deep-links straight to
/// that project's detail screen.
struct InProgressWidget: Widget {
    let kind = "WorkshopInProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            InProgressWidgetView(snapshot: entry.snapshot)
                .containerBackground(WSWidget.flap, for: .widget)
        }
        .configurationDisplayName("In-Progress Projects")
        .description("Your active builds, one tap from their detail screen.")
        .contentMarginsDisabled()
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct InProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WorkshopWidgetSnapshot

    /// The board always shows a fixed number of slots; unfilled ones stay
    /// blank, the way a departure board reads between arrivals.
    private var maxRows: Int { family == .systemMedium ? 2 : 6 }

    var body: some View {
        if !snapshot.signedIn {
            SignedOutView()
        } else {
            VStack(spacing: 0) {
                WSHeader(title: "In Progress", trailing: wsPad(snapshot.inProgressCount))
                let shown = Array(snapshot.inProgress.prefix(maxRows))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, project in
                        if i > 0 { Rectangle().fill(WSWidget.line).frame(height: 1) }
                        row(project).frame(maxHeight: .infinity).background(WSWidget.flap)
                    }
                    ForEach(shown.count..<maxRows, id: \.self) { i in
                        if i > 0 || !shown.isEmpty {
                            Rectangle().fill(WSWidget.line).frame(height: 1)
                        }
                        emptySlot(first: shown.isEmpty && i == 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WSWidget.flapShade)
        }
    }

    /// An unfilled slot. The first one on an empty board says so; the rest
    /// stay blank shaded board.
    private func emptySlot(first: Bool) -> some View {
        HStack {
            if first { WSCaps("No active builds", size: 9) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A departure row: title in tracked caps, parts on flaps at the platform
    /// end — the same grammar as the app's project cards.
    private func row(_ project: WorkshopWidgetSnapshot.InProgressProject) -> some View {
        Link(destination: WSDeepLink.project(project.id)) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title.uppercased())
                        .font(WSWidget.board(11, .bold)).tracking(0.6)
                        .foregroundStyle(WSWidget.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text(project.difficulty)
                        .font(WSWidget.ui(10)).foregroundStyle(WSWidget.subtle).lineLimit(1)
                }
                Spacer(minLength: 4)
                WSFlapNumber(value: wsPad(project.partsCount), size: 10)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
    }
}


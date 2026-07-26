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
                .containerBackground(WSWidget.cream, for: .widget)
        }
        .configurationDisplayName("In-Progress Projects")
        .description("Your active builds, one tap from their detail screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct InProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WorkshopWidgetSnapshot

    private var maxRows: Int { family == .systemMedium ? 2 : 5 }

    var body: some View {
        if !snapshot.signedIn {
            SignedOutView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                header
                if snapshot.inProgress.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.inProgress.prefix(maxRows)) { project in
                            row(project)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill").font(.footnote).foregroundStyle(WSWidget.accent)
            Text("In Progress").font(.headline).foregroundStyle(WSWidget.accent)
            Spacer()
            Text("\(snapshot.inProgressCount)")
                .font(.caption2.weight(.bold)).foregroundStyle(WSWidget.subtle)
        }
    }

    private var emptyState: some View {
        Text("No active builds right now.")
            .font(.caption).foregroundStyle(WSWidget.subtle)
    }

    private func row(_ project: WorkshopWidgetSnapshot.InProgressProject) -> some View {
        Link(destination: WSDeepLink.project(project.id)) {
            HStack(spacing: 8) {
                Circle().fill(WSWidget.accent).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.title).font(.caption.weight(.medium)).foregroundStyle(WSWidget.ink).lineLimit(1)
                    Text("\(project.partsCount) part\(project.partsCount == 1 ? "" : "s") · \(project.difficulty)")
                        .font(.system(size: 10)).foregroundStyle(WSWidget.subtle).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

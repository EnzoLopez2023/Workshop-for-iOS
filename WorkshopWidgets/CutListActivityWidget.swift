import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents
import NintekKit

/// Toggles one part's checked-off state directly from the Live Activity's
/// Lock Screen/Dynamic Island button — no app launch, no network. Updates
/// the Activity's own state in place, since this checklist is intentionally
/// local-only (see `CutListActivityAttributes`).
struct ToggleCutPartIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Cut Part"

    @Parameter(title: "Part ID")
    var partId: Int

    init() {}
    init(partId: Int) { self.partId = partId }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<CutListActivityAttributes>.activities.first else {
            return .result()
        }
        var checked = activity.content.state.checkedPartIds
        if checked.contains(partId) { checked.remove(partId) } else { checked.insert(partId) }
        await activity.update(.init(state: .init(checkedPartIds: checked), staleDate: nil))
        return .result()
    }
}

struct CutListActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CutListActivityAttributes.self) { context in
            CutListLockScreenView(context: context)
                .activityBackgroundTint(WSWidget.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "hammer.fill").foregroundStyle(WSWidget.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(progressText(context.state, of: context.attributes))
                        .font(.caption2.weight(.semibold)).foregroundStyle(WSWidget.subtle)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.projectTitle).font(.caption.weight(.semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CutListChecklistView(context: context)
                }
            } compactLeading: {
                Image(systemName: "hammer.fill").foregroundStyle(WSWidget.accent)
            } compactTrailing: {
                Text(progressText(context.state, of: context.attributes))
                    .font(.caption2.weight(.bold)).foregroundStyle(WSWidget.accent)
            } minimal: {
                Image(systemName: "hammer.fill").foregroundStyle(WSWidget.accent)
            }
            .widgetURL(WSDeepLink.project(context.attributes.projectId))
        }
    }

    private func progressText(_ state: CutListActivityAttributes.ContentState, of attrs: CutListActivityAttributes) -> String {
        "\(state.checkedPartIds.count)/\(attrs.parts.count)"
    }
}

/// The Lock Screen banner — full checklist, tappable rows.
private struct CutListLockScreenView: View {
    let context: ActivityViewContext<CutListActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "hammer.fill").font(.footnote).foregroundStyle(WSWidget.accent)
                Text(context.attributes.projectTitle).font(.subheadline.weight(.bold)).foregroundStyle(WSWidget.ink).lineLimit(1)
                Spacer()
                Text("\(context.state.checkedPartIds.count)/\(context.attributes.parts.count) cut")
                    .font(.caption.weight(.semibold)).foregroundStyle(WSWidget.subtle)
            }
            CutListChecklistView(context: context, maxRows: 5)
        }
        .padding(14)
    }
}

/// Shared checklist rows — used by both the Lock Screen view and the Dynamic
/// Island's expanded region. Each row is its own button (via `Button(intent:)`)
/// so tapping it fires `ToggleCutPartIntent` in place, no app launch.
private struct CutListChecklistView: View {
    let context: ActivityViewContext<CutListActivityAttributes>
    var maxRows: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(context.attributes.parts.prefix(maxRows), id: \.id) { part in
                let checked = context.state.checkedPartIds.contains(part.id)
                Button(intent: ToggleCutPartIntent(partId: part.id)) {
                    HStack(spacing: 8) {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked ? WSWidget.accent : WSWidget.subtle)
                        Text("\(part.partName) ×\(part.qty)")
                            .font(.system(size: 13))
                            .foregroundStyle(checked ? WSWidget.subtle : WSWidget.ink)
                            .strikethrough(checked)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
            if context.attributes.parts.count > maxRows {
                Text("+ \(context.attributes.parts.count - maxRows) more")
                    .font(.system(size: 11)).foregroundStyle(WSWidget.subtle)
            }
        }
    }
}

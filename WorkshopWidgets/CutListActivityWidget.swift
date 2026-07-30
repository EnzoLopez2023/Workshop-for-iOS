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
                .activityBackgroundTint(WSWidget.concourse)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "hammer.fill").foregroundStyle(WSWidget.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(progressText(context.state, of: context.attributes))
                        .font(WSWidget.board(11, .bold)).foregroundStyle(WSWidget.accentFill)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.projectTitle.uppercased())
                        .font(WSWidget.board(11, .bold)).tracking(0.6).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CutListChecklistView(context: context)
                }
            } compactLeading: {
                Image(systemName: "hammer.fill").foregroundStyle(WSWidget.accent)
            } compactTrailing: {
                Text(progressText(context.state, of: context.attributes))
                    .font(WSWidget.board(11, .bold)).foregroundStyle(WSWidget.accentFill)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 9)).foregroundStyle(WSWidget.accentFill)
                Text(context.attributes.projectTitle.uppercased())
                    .font(WSWidget.board(12, .bold)).tracking(0.8)
                    .foregroundStyle(WSWidget.ink).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                // Cut progress is the one live figure here, so it gets flaps.
                WSFlapNumber(value: "\(context.state.checkedPartIds.count)", size: 11,
                             tone: WSWidget.accentFill)
                WSCaps("of \(context.attributes.parts.count)", size: 8.5)
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
                        RoundedRectangle(cornerRadius: WSWidget.rFlap)
                            .fill(checked ? WSWidget.accentFill : .clear)
                            .frame(width: 13, height: 13)
                            .overlay(RoundedRectangle(cornerRadius: WSWidget.rFlap)
                                .strokeBorder(checked ? WSWidget.accentFill : WSWidget.subtle,
                                              lineWidth: 1.5))
                        Text(part.partName)
                            .font(WSWidget.ui(13, .medium))
                            .foregroundStyle(checked ? WSWidget.subtle : WSWidget.ink)
                            .strikethrough(checked)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("×\(part.qty)")
                            .font(WSWidget.board(11, .semibold))
                            .foregroundStyle(WSWidget.subtle)
                    }
                }
                .buttonStyle(.plain)
            }
            if context.attributes.parts.count > maxRows {
                WSCaps("+ \(context.attributes.parts.count - maxRows) more", size: 8.5)
            }
        }
    }
}

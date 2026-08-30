import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents
import NintekKit

/// Checks a shopping-list item off directly from the Live Activity's Lock
/// Screen/Dynamic Island row — no app launch. Unlike `ToggleCutPartIntent`
/// (purely local, ephemeral state), checking a material off here is a real
/// purchase: this updates the Activity's own state for immediate feedback
/// *and* queues the same App-Group reconciliation `ToggleShoppingItemIntent`
/// (Phase 7.2's widget button) already uses, so the authenticated write
/// happens the next time the app opens (`DashboardView.load()`). One-way —
/// a real purchase isn't something a Live Activity tap should be able to
/// silently undo.
struct ToggleShoppingActivityItemIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Check Off Shopping Item"

    @Parameter(title: "Item ID")
    var itemId: Int

    init() {}
    init(itemId: Int) { self.itemId = itemId }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<ShoppingActivityAttributes>.activities.first else {
            return .result()
        }
        var purchased = activity.content.state.purchasedItemIds
        purchased.insert(itemId)
        await activity.update(.init(state: .init(purchasedItemIds: purchased), staleDate: nil))

        if var snapshot = WorkshopWidgetStore.load() {
            snapshot.shoppingItems.removeAll { $0.id == itemId }
            WorkshopWidgetStore.save(snapshot)
        }
        WorkshopWidgetStore.requestShoppingToggle(itemId: itemId)
        return .result()
    }
}

struct ShoppingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingActivityAttributes.self) { context in
            ShoppingLockScreenView(context: context)
                .activityBackgroundTint(WSWidget.canvas)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "cart.fill").foregroundStyle(WSWidget.annotation)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(progressText(context.state, of: context.attributes))
                        .font(WSWidget.rounded(11, .bold)).foregroundStyle(WSWidget.annotationFill)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("SHOPPING LIST")
                        .font(WSWidget.rounded(11, .bold)).tracking(0.6).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ShoppingChecklistView(context: context)
                }
            } compactLeading: {
                Image(systemName: "cart.fill").foregroundStyle(WSWidget.annotation)
            } compactTrailing: {
                Text(progressText(context.state, of: context.attributes))
                    .font(WSWidget.rounded(11, .bold)).foregroundStyle(WSWidget.annotationFill)
            } minimal: {
                Image(systemName: "cart.fill").foregroundStyle(WSWidget.annotation)
            }
            .widgetURL(WSDeepLink.dashboard)
        }
    }

    private func progressText(_ state: ShoppingActivityAttributes.ContentState, of attrs: ShoppingActivityAttributes) -> String {
        "\(state.purchasedItemIds.count)/\(attrs.items.count)"
    }
}

/// The Lock Screen banner — full checklist, tappable rows.
private struct ShoppingLockScreenView: View {
    let context: ActivityViewContext<ShoppingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 9)).foregroundStyle(WSWidget.annotationFill)
                Text("SHOPPING LIST")
                    .font(WSWidget.rounded(12, .bold)).tracking(0.8)
                    .foregroundStyle(WSWidget.ink).lineLimit(1)
                Spacer(minLength: 6)
                WSMetric(value: "\(context.state.purchasedItemIds.count)", size: 11,
                             tone: WSWidget.annotationFill)
                WSLabel("of \(context.attributes.items.count)", size: 8.5)
            }
            ShoppingChecklistView(context: context, maxRows: 5)
        }
        .padding(14)
    }
}

/// Shared checklist rows — used by both the Lock Screen view and the Dynamic
/// Island's expanded region. Each row is its own button (via `Button(intent:)`)
/// so tapping it fires `ToggleShoppingActivityItemIntent` in place.
private struct ShoppingChecklistView: View {
    let context: ActivityViewContext<ShoppingActivityAttributes>
    var maxRows: Int = 3

    var body: some View {
        let remaining = context.attributes.items.filter { !context.state.purchasedItemIds.contains($0.id) }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(remaining.prefix(maxRows), id: \.id) { item in
                Button(intent: ToggleShoppingActivityItemIntent(itemId: item.id)) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: WSWidget.rCompact)
                            .fill(.clear)
                            .frame(width: 13, height: 13)
                            .overlay(RoundedRectangle(cornerRadius: WSWidget.rCompact)
                                .strokeBorder(WSWidget.muted, lineWidth: 1.5))
                        Text(item.name)
                            .font(WSWidget.ui(13, .medium))
                            .foregroundStyle(WSWidget.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let qty = item.qtyLabel {
                            Text(qty)
                                .font(WSWidget.rounded(11, .semibold))
                                .foregroundStyle(WSWidget.muted)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if remaining.isEmpty {
                WSLabel("All items checked off", size: 9)
            } else if remaining.count > maxRows {
                WSLabel("+ \(remaining.count - maxRows) more", size: 8.5)
            }
        }
    }
}

import SwiftUI
import WidgetKit
import AppIntents
import NintekKit

/// A quick shopping-list checkoff widget (Phase 7.2) — the top few unpurchased
/// items across all projects, each row a real button: tapping it checks the
/// item off right from the Home Screen, no app launch. See
/// `ToggleShoppingItemIntent` for how the write reaches the server without
/// the widget extension needing to authenticate.
struct ShoppingListWidget: Widget {
    let kind = "WorkshopShoppingList"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ShoppingListWidgetView(snapshot: entry.snapshot)
                .containerBackground(WSWidget.cream, for: .widget)
        }
        .configurationDisplayName("Shopping List")
        .description("Check off materials as you pick them up — right from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ShoppingListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WorkshopWidgetSnapshot

    private var maxRows: Int { family == .systemSmall ? 3 : 5 }

    var body: some View {
        if !snapshot.signedIn {
            SignedOutView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill").font(.caption2).foregroundStyle(WSWidget.accent)
                    Text("SHOPPING LIST").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(WSWidget.subtle)
                }
                if snapshot.shoppingItems.isEmpty {
                    Text("All caught up.").font(.system(size: 12)).foregroundStyle(WSWidget.subtle)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(snapshot.shoppingItems.prefix(maxRows)) { item in
                            Button(intent: ToggleShoppingItemIntent(itemId: item.id)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square").foregroundStyle(WSWidget.subtle)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(item.name).font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(WSWidget.ink).lineLimit(1)
                                        if let q = item.qtyLabel, !q.isEmpty {
                                            Text(q).font(.system(size: 10)).foregroundStyle(WSWidget.subtle)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(WSDeepLink.dashboard)
        }
    }
}

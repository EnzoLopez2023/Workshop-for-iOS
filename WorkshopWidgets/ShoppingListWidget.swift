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
                .containerBackground(WSWidget.flap, for: .widget)
        }
        .configurationDisplayName("Shopping List")
        .description("Check off materials as you pick them up — right from the Home Screen.")
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ShoppingListWidgetView: View {
    let snapshot: WorkshopWidgetSnapshot

    /// Small and medium widgets are the same height (155pt), so both fit the
    /// same number of slots — medium just has the width to show longer names.
    /// Unfilled slots stay blank board rather than collapsing the card.
    private var maxRows: Int { 3 }

    var body: some View {
        if !snapshot.signedIn {
            SignedOutView()
        } else {
            VStack(spacing: 0) {
                WSHeader(title: "Shopping List")
                let shown = Array(snapshot.shoppingItems.prefix(maxRows))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { Rectangle().fill(WSWidget.line).frame(height: 1) }
                        Button(intent: ToggleShoppingItemIntent(itemId: item.id)) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: WSWidget.rFlap)
                                    .strokeBorder(WSWidget.subtle, lineWidth: 1.5)
                                    .frame(width: 13, height: 13)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.name).font(WSWidget.ui(12, .medium))
                                        .foregroundStyle(WSWidget.ink).lineLimit(1)
                                    if let q = item.qtyLabel, !q.isEmpty {
                                        Text(q).font(WSWidget.board(9))
                                            .foregroundStyle(WSWidget.subtle).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .frame(maxHeight: .infinity)
                        .background(WSWidget.flap)
                    }
                    ForEach(shown.count..<maxRows, id: \.self) { i in
                        if i > 0 || !shown.isEmpty {
                            Rectangle().fill(WSWidget.line).frame(height: 1)
                        }
                        HStack {
                            if shown.isEmpty && i == 0 { WSCaps("All caught up", size: 9) }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WSWidget.flapShade)
            .widgetURL(WSDeepLink.dashboard)
        }
    }
}


import SwiftUI
import WidgetKit
import NintekKit

/// Shopping list — parity with `ShoppingList.tsx`: unpurchased materials
/// grouped by project, item count + estimated total, a "Show purchased" local
/// filter toggle, and an optimistic purchased toggle per item (matches the
/// web's revert-on-failure pattern).
struct ShoppingView: View {
    let api: WorkshopAPI

    @State private var items: [ShoppingItem] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var showPurchased = false
    @State private var exportURL: IdentifiableURL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    } else if let err = loadError {
                        errorState(err)
                    } else if grouped.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 26) {
                            ForEach(grouped, id: \.id) { group in
                                projectGroup(group)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .contentColumn(700)
                .padding(20)
            }
            .boardBackground()
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BoardToolbarButton(symbol: "printer", label: "Print List", tone: .amber) {
                        if let url = ShoppingListPDFExporter.export(groups: grouped, allItems: items) {
                            exportURL = IdentifiableURL(url: url)
                        }
                    }
                    .disabled(grouped.isEmpty)
                }
                .boardToolbarItem()
            }
            .sheet(item: $exportURL) { ActivityShareSheet(items: [$0.url]) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.onSteel)
                    .frame(width: 36, height: 36)
                    .background(Theme.steel, in: RoundedRectangle(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shopping List").font(Theme.display(21)).foregroundStyle(Theme.ink)
                    Text(summaryText)
                        .font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                }
            }

            Toggle(isOn: $showPurchased) {
                Text("Show purchased").font(Theme.ui(14, .regular)).foregroundStyle(Theme.ink)
            }
                .toggleStyle(.flap)
        }
    }

    private var summaryText: String {
        let unpurchasedCount = items.filter { !$0.purchased }.count
        if unpurchasedCount == 0 { return "All items purchased." }
        let total = items.filter { !$0.purchased }.reduce(0.0) { $0 + $1.cost }
        return "\(unpurchasedCount) item\(unpurchasedCount == 1 ? "" : "s") needed · est. \(money(total))"
    }

    // MARK: Groups

    struct ProjectGroup: Identifiable {
        let id: Int
        let title: String
        var items: [ShoppingItem]
    }

    private var grouped: [ProjectGroup] {
        let visible = showPurchased ? items : items.filter { !$0.purchased }
        var order: [Int] = []
        var map: [Int: ProjectGroup] = [:]
        for item in visible {
            if map[item.projectId] == nil {
                order.append(item.projectId)
                map[item.projectId] = ProjectGroup(id: item.projectId, title: item.projectTitle, items: [])
            }
            map[item.projectId]!.items.append(item)
        }
        return order.compactMap { map[$0] }
    }

    private func projectGroup(_ group: ProjectGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.title.uppercased())
                .font(Theme.ui(11, .bold)).tracking(1.2).foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().overlay(Theme.line) }
                    itemRow(item)
                }
            }
            .background(Theme.flap).clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button { Task { await togglePurchased(item) } } label: {
            HStack(spacing: 14) {
                Image(systemName: item.purchased ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.purchased ? Theme.accent : Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(Theme.ui(15, .medium))
                        .foregroundStyle(item.purchased ? Theme.muted : Theme.ink)
                        .strikethrough(item.purchased)
                    if let q = item.qtyLabel, !q.isEmpty {
                        Text(q).font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                if item.cost > 0 {
                    Text(money(item.cost)).font(Theme.board(14, .regular))
                        .foregroundStyle(item.purchased ? Theme.muted : Theme.ink).strikethrough(item.purchased)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.purchased)
    }

    // MARK: States

    private var emptyState: some View {
        Text(items.isEmpty ? "No materials across your projects yet." : "Everything has been purchased.")
            .font(Theme.ui(14, .regular)).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 50)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn’t load shopping list").font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(Theme.ink)
            Text(msg).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
        }.frame(maxWidth: .infinity).padding(.top, 60)
    }

    // MARK: Data

    private func load() async {
        loading = items.isEmpty; loadError = nil
        do {
            items = try await api.shoppingList()
            syncWidgetSnapshot()
        } catch { loadError = error.localizedDescription }
        loading = false
    }

    private func togglePurchased(_ item: ShoppingItem) async {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let next = !item.purchased
        items[idx].purchased = next
        syncWidgetSnapshot()
        do { try await api.setPurchased(id: item.id, purchased: next) }
        catch { await load() }
    }

    /// Publishes the top unpurchased items for the Home Screen widget's
    /// checkbox row (Phase 7.2) — merged in, not overwritten, so it doesn't
    /// clobber the project-stats half of the snapshot Dashboard writes.
    private func syncWidgetSnapshot() {
        let preview = items.filter { !$0.purchased }.prefix(5).map {
            WorkshopWidgetSnapshot.ShoppingPreviewItem(id: $0.id, name: $0.name, qtyLabel: $0.qtyLabel)
        }
        WorkshopWidgetStore.mergeShoppingItems(Array(preview))
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private func money(_ n: Double) -> String { String(format: "$%.2f", n) }

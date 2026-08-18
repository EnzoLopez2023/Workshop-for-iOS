import SwiftUI
import WidgetKit
import NintekKit

/// Shopping list — parity with `ShoppingList.tsx`: unpurchased materials
/// grouped by project, item count + estimated total, a "Show purchased" local
/// filter toggle, and an optimistic purchased toggle per item (matches the
/// web's revert-on-failure pattern).
struct ShoppingView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel

    @State private var items: [ShoppingItem] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var showPurchased = false
    @State private var exportURL: IdentifiableURL?
    @State private var trackingShopping = ShoppingActivityController.isTracking
    @State private var mutationTokens: [Int: UUID] = [:]
    @State private var loadGeneration = 0

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
                if !model.isDemoMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Lock Screen / Dynamic Island checklist for a shopping
                        // trip (Phase 7.9+) — mirrors ProjectDetailView's "Track
                        // Cuts" toggle exactly, one Live Activity at a time.
                        BoardToolbarButton(symbol: trackingShopping ? "checklist.checked" : "checklist",
                                           label: "Track Shopping", tone: trackingShopping ? .amber : .steel) {
                            Task {
                                if trackingShopping {
                                    await ShoppingActivityController.end()
                                } else {
                                    await ShoppingActivityController.start(items: items.filter { !$0.purchased })
                                }
                                trackingShopping.toggle()
                            }
                        }
                        .disabled(items.allSatisfy { $0.purchased })
                        .accessibilityValue(trackingShopping ? "On" : "Off")
                        .accessibilityAddTraits(trackingShopping ? .isSelected : [])
                    }
                    .boardToolbarItem()
                }
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep)
                    .frame(width: 40, height: 40)
                    .background(
                        Theme.tint(Theme.accent),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shopping List")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }

            Toggle(isOn: $showPurchased) {
                Text("Show purchased")
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }
            .toggleStyle(.switch)
            .tint(Theme.accentDeep)
            .padding(16)
            .planGlass(elevated: false)
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
            Text(group.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().overlay(Theme.line) }
                    itemRow(item)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
            )
        }
    }

    @ViewBuilder private func itemRow(_ item: ShoppingItem) -> some View {
        if model.isDemoMode {
            itemRowContent(item)
                .accessibilityElement(children: .combine)
                .accessibilityValue(item.purchased ? "Purchased" : "Not purchased")
                .accessibilityHint("Read-only demo")
        } else {
            Button { Task { await togglePurchased(item) } } label: {
                itemRowContent(item)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: item.purchased)
            .disabled(mutationTokens[item.id] != nil)
            .accessibilityElement(children: .combine)
            .accessibilityValue(item.purchased ? "Purchased" : "Not purchased")
            .accessibilityHint(item.purchased ? "Marks this item as not purchased" : "Marks this item as purchased")
            .accessibilityAddTraits(item.purchased ? [.isButton, .isSelected] : .isButton)
        }
    }

    private func itemRowContent(_ item: ShoppingItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.purchased ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(item.purchased ? Theme.accentDeep : Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(item.purchased ? Theme.muted : Theme.ink)
                    .strikethrough(item.purchased)
                if let quantity = item.qtyLabel, !quantity.isEmpty {
                    Text(quantity)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if item.cost > 0 {
                Text(money(item.cost))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.purchased ? Theme.muted : Theme.ink)
                    .strikethrough(item.purchased)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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
        loadGeneration &+= 1
        let generation = loadGeneration
        loading = items.isEmpty; loadError = nil
        do {
            var refreshed = try await api.shoppingList()
            guard generation == loadGeneration else { return }
            let pendingValues = Dictionary(
                uniqueKeysWithValues: items.compactMap { item in
                    mutationTokens[item.id] == nil ? nil : (item.id, item.purchased)
                }
            )
            for index in refreshed.indices {
                if let pending = pendingValues[refreshed[index].id] {
                    refreshed[index].purchased = pending
                }
            }
            items = refreshed
            if !model.isDemoMode { syncWidgetSnapshot() }
        } catch {
            guard generation == loadGeneration else { return }
            loadError = error.localizedDescription
        }
        loading = false
    }

    private func togglePurchased(_ item: ShoppingItem) async {
        guard !model.isDemoMode,
              mutationTokens[item.id] == nil,
              let idx = items.firstIndex(where: { $0.id == item.id })
        else { return }
        loadGeneration &+= 1
        let token = UUID()
        mutationTokens[item.id] = token
        let previous = items[idx].purchased
        let next = !previous
        items[idx].purchased = next
        syncWidgetSnapshot()
        do {
            try await api.setPurchased(id: item.id, purchased: next)
        } catch {
            if let current = items.firstIndex(where: { $0.id == item.id }) {
                items[current].purchased = previous
            }
            syncWidgetSnapshot()
            ToastCenter.shared.error("Could not update \(item.name)")
            Haptics.error()
        }
        guard mutationTokens[item.id] == token else { return }
        loadGeneration &+= 1
        mutationTokens[item.id] = nil
    }

    /// Publishes the top unpurchased items for the Home Screen widget's
    /// checkbox row (Phase 7.2) — merged in, not overwritten, so it doesn't
    /// clobber the project-stats half of the snapshot Dashboard writes.
    private func syncWidgetSnapshot() {
        guard !model.isDemoMode else { return }
        let preview = items.filter { !$0.purchased }.prefix(5).map {
            WorkshopWidgetSnapshot.ShoppingPreviewItem(id: $0.id, name: $0.name, qtyLabel: $0.qtyLabel)
        }
        WorkshopWidgetStore.mergeShoppingItems(Array(preview))
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private func money(_ n: Double) -> String { String(format: "$%.2f", n) }

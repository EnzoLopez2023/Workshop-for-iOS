import SwiftUI
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
            .creamBackground()
            .navigationTitle("Shopping List")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "cart.fill").font(.system(size: 18)).foregroundStyle(Theme.accent)
                Text("Shopping List").font(Theme.display(24)).foregroundStyle(Theme.ink)
            }
            Text(summaryText)
                .font(.system(size: 14)).foregroundStyle(Theme.subtle)

            Toggle(isOn: $showPurchased) {
                Text("Show purchased").font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
            }
            .tint(Theme.accent)
            .padding(.top, 4)
        }
    }

    private var summaryText: String {
        let unpurchasedCount = items.filter { !$0.purchased }.count
        if unpurchasedCount == 0 { return "All items purchased." }
        let total = items.filter { !$0.purchased }.reduce(0.0) { $0 + $1.cost }
        return "\(unpurchasedCount) item\(unpurchasedCount == 1 ? "" : "s") needed · est. \(money(total))"
    }

    // MARK: Groups

    private struct ProjectGroup: Identifiable {
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
                .font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(Theme.subtle)
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().overlay(Theme.line) }
                    itemRow(item)
                }
            }
            .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button { Task { await togglePurchased(item) } } label: {
            HStack(spacing: 14) {
                Image(systemName: item.purchased ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.purchased ? Theme.accent : Theme.subtle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 15, weight: .medium))
                        .foregroundStyle(item.purchased ? Theme.subtle : Theme.ink)
                        .strikethrough(item.purchased)
                    if let q = item.qtyLabel, !q.isEmpty {
                        Text(q).font(.system(size: 12)).foregroundStyle(Theme.subtle)
                    }
                }
                Spacer()
                if item.cost > 0 {
                    Text(money(item.cost)).font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(item.purchased ? Theme.subtle : Theme.ink).strikethrough(item.purchased)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: States

    private var emptyState: some View {
        Text(items.isEmpty ? "No materials across your projects yet." : "Everything has been purchased.")
            .font(.system(size: 14)).foregroundStyle(Theme.subtle)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 50)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn’t load shopping list").font(.headline).foregroundStyle(Theme.ink)
            Text(msg).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
        }.frame(maxWidth: .infinity).padding(.top, 60)
    }

    // MARK: Data

    private func load() async {
        loading = items.isEmpty; loadError = nil
        do { items = try await api.shoppingList() }
        catch { loadError = error.localizedDescription }
        loading = false
    }

    private func togglePurchased(_ item: ShoppingItem) async {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let next = !item.purchased
        items[idx].purchased = next
        do { try await api.setPurchased(id: item.id, purchased: next) }
        catch { await load() }
    }
}

private func money(_ n: Double) -> String { String(format: "$%.2f", n) }

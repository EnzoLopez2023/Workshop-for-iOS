import SwiftUI

/// Left-to-right wrapping layout for chips/tags (lifted from the ShopKeep port).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A rounded tag chip — the web `.chip`.
struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.ui(13, .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.flapShade, in: RoundedRectangle(cornerRadius: Theme.rFlap))
            .overlay(RoundedRectangle(cornerRadius: Theme.rFlap).strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// A labelled group of chips (WOOD / TOOLS on the detail page).
struct ChipGroup: View {
    let label: String
    let items: [String]
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(label).font(Theme.ui(11, .bold)).tracking(1.2).foregroundStyle(Theme.muted)
                FlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { Chip(text: $0) }
                }
            }
        }
    }
}

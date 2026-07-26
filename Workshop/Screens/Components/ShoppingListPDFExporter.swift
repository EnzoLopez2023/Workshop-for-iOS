import SwiftUI
import UIKit
import NintekKit

/// Renders the shopping list to a single-page portrait PDF — the native
/// replacement for the web's print-window HTML document (`ShoppingList.tsx`
/// `printShoppingList`). Reuses `ShoppingListPrintView`'s SwiftUI layout via
/// `ImageRenderer`, same pattern as `CutPlanPDFExporter`.
@MainActor
enum ShoppingListPDFExporter {
    // US Letter portrait at 72dpi, 0.75in margins — matches the web's
    // `@page { size: letter portrait; margin: 0.75in }`.
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 54

    static func export(groups: [ShoppingView.ProjectGroup], allItems: [ShoppingItem]) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let contentSize = CGSize(width: pageWidth - margin * 2, height: pageHeight - margin * 2)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let page = ShoppingListPrintView(groups: groups, allItems: allItems)
                .frame(width: contentSize.width, height: contentSize.height, alignment: .top)
                .background(Color.white)
            let imageRenderer = ImageRenderer(content: page)
            imageRenderer.scale = 2
            if let image = imageRenderer.uiImage {
                image.draw(in: CGRect(origin: CGPoint(x: margin, y: margin), size: contentSize))
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shopping-list-\(Int(Date().timeIntervalSince1970)).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

/// Print-formatted shopping list — parity with the web's `printShoppingList` HTML.
private struct ShoppingListPrintView: View {
    let groups: [ShoppingView.ProjectGroup]
    let allItems: [ShoppingItem]

    private var unpurchased: [ShoppingItem] { allItems.filter { !$0.purchased } }
    private var total: Double { unpurchased.reduce(0) { $0 + $1.cost } }
    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Shopping List").font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
                Text("\(unpurchased.count) items · \(dateString)")
                    .font(.system(size: 10)).foregroundStyle(Color(white: 0.5))
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color(red: 0.627, green: 0.322, blue: 0.176)).frame(width: 4)
            }

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title.uppercased())
                        .font(.system(size: 9, weight: .bold)).tracking(1.2)
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color(white: 0.91)).frame(height: 1)
                        }
                    ForEach(group.items) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color(white: 0.55), lineWidth: 1.2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(item.purchased ? Color(red: 0.627, green: 0.322, blue: 0.176) : .clear))
                                .frame(width: 12, height: 12)
                            Text(item.name)
                                .font(.system(size: 11))
                                .foregroundStyle(item.purchased ? Color(white: 0.5) : .black)
                                .strikethrough(item.purchased)
                            if let q = item.qtyLabel, !q.isEmpty {
                                Text(q).font(.system(size: 9)).foregroundStyle(Color(white: 0.5))
                            }
                            Spacer()
                            if item.cost > 0 {
                                Text(money(item.cost))
                                    .font(.system(size: 11))
                                    .foregroundStyle(item.purchased ? Color(white: 0.5) : .black)
                                    .strikethrough(item.purchased)
                            }
                        }
                    }
                }
            }

            if total > 0 {
                HStack {
                    Text("Estimated Total").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(money(total)).font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.top, 8)
                .overlay(alignment: .top) {
                    Rectangle().fill(.black).frame(height: 2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func money(_ n: Double) -> String { String(format: "$%.2f", n) }
}

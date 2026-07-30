import SwiftUI
import UIKit
import NintekKit

/// Renders a completed cut plan to a multi-page landscape PDF (one page per
/// sheet + a legend page) — the native replacement for the web's print-window
/// SVG document. Reuses `CutPlanSheetView`'s existing SwiftUI drawing via
/// `ImageRenderer` rather than re-implementing the diagram in raw CoreGraphics,
/// so the printed page always matches what's shown on screen.
@MainActor
enum CutPlanPDFExporter {
    // US Letter landscape at 72dpi, 0.45in margins — matches the web's
    // `@page { size: landscape; margin: 0.45in }`.
    private static let pageWidth: CGFloat = 792
    private static let pageHeight: CGFloat = 612
    private static let margin: CGFloat = 32

    /// Builds the PDF and writes it to a temp file, returning its URL (nil on
    /// any rendering/write failure).
    static func export(result: CutPlanResult, colorMap: [String: String], stockLabel: (String) -> String?) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let contentSize = CGSize(width: pageWidth - margin * 2, height: pageHeight - margin * 2)

        let data = renderer.pdfData { ctx in
            for layout in result.layouts {
                ctx.beginPage()
                drawPage(
                    CutPlanSheetView(layout: layout, sheetNumber: layout.sheetIndex + 1,
                                     totalSheets: result.totalSheets, colorMap: colorMap,
                                     stockLabel: stockLabel(layout.stockId)),
                    size: contentSize
                )
            }
            ctx.beginPage()
            drawPage(LegendPageView(colorMap: colorMap), size: contentSize)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cut-plan-\(Int(Date().timeIntervalSince1970)).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func drawPage(_ content: some View, size: CGSize) {
        let page = content.frame(width: size.width, height: size.height).background(Color.white)
        let imageRenderer = ImageRenderer(content: page)
        imageRenderer.scale = 2
        if let image = imageRenderer.uiImage {
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: margin), size: size))
        }
    }
}

/// The PDF's final page — the color legend, matching the web's print-doc legend.
private struct LegendPageView: View {
    let colorMap: [String: String]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LEGEND").font(Theme.ui(14, .bold)).tracking(1.5).foregroundStyle(.secondary)
            FlowLayout(spacing: 14) {
                ForEach(colorMap.sorted(by: { $0.key < $1.key }), id: \.key) { name, hex in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: hex)).frame(width: 14, height: 14)
                        Text(name).font(Theme.ui(13, .regular)).foregroundStyle(.black)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Thin wrapper around `UIActivityViewController` for sharing an exported file
/// (e.g. the cut-plan PDF) via the system share sheet.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

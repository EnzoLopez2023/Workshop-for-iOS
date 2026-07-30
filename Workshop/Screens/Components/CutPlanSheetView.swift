import SwiftUI
import NintekKit

/// Renders one sheet layout as a scaled diagram — SwiftUI `Canvas` port of
/// `CutPlanSheet.tsx`'s SVG. Background rect, one colored rect per placed
/// piece with part-name + fractional-dimension labels (rotated for portrait
/// pieces, truncated when the piece is too small to fit its label), and an
/// outer sheet border.
///
/// Unlike the web (which computes an SVG viewBox and lets the browser scale
/// physical stroke/font sizes down via `1/scale`/`9/scale` tricks), this
/// Canvas draws directly in screen points: `size` from the draw closure
/// already reflects the final on-screen scale (via `.aspectRatio(.fit)`), so
/// every "divide by scale" in the original becomes a plain constant here.
struct CutPlanSheetView: View {
    let layout: SheetLayout
    let sheetNumber: Int
    let totalSheets: Int
    let colorMap: [String: String]
    let stockLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Canvas { context, size in draw(context: context, size: size) }
                .aspectRatio(layout.sheetLength / max(layout.sheetWidth, 1), contentMode: .fit)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1.5))
        }
    }

    private var header: some View {
        let parts = headerParts
        return HStack(spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                if i > 0 { Text("·").opacity(0.4) }
                Text(part)
                    .font(Theme.board(11, i == 0 ? .semibold : .regular))
                    .foregroundStyle(i == 0 ? Theme.ink : Theme.muted)
            }
        }
        .font(Theme.ui(13, .regular))
        .foregroundStyle(Theme.muted)
    }

    private var headerParts: [String] {
        var parts = [
            "Sheet \(sheetNumber) of \(totalSheets)",
            "\(fmtDim(layout.sheetLength)) × \(fmtDim(layout.sheetWidth))",
            "Yield: \(String(format: "%.1f", 100 - layout.wastePercent))%",
        ]
        if let stockLabel, !stockLabel.isEmpty { parts.append(stockLabel) }
        return parts
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        guard layout.sheetLength > 0, layout.sheetWidth > 0 else { return }
        let scale = size.width / layout.sheetLength

        // Sheet background.
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: CutPlanBoard.sheet)))

        for p in layout.placed {
            let rect = CGRect(x: p.x * scale, y: p.y * scale, width: p.length * scale, height: p.width * scale)
            let fill = Color(hex: colorMap[p.partName] ?? CutPlanBoard.palette[0])
            let path = Path(roundedRect: rect, cornerRadius: 0.15 * scale)
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(.black.opacity(0.22)), lineWidth: 1)

            let pxW = rect.width, pxH = rect.height
            guard pxW >= 12, pxH >= 12 else { continue }

            let isPortrait = p.width > p.length
            let cx = rect.midX, cy = rect.midY
            let textAvailPx = isPortrait ? pxH : pxW
            let maxChars = max(3, Int(textAvailPx / 6.5))
            let label = p.partName.count > maxChars ? String(p.partName.prefix(maxChars - 1)) + "…" : p.partName
            let dimLabel = "\(fmtDim(p.length)) × \(fmtDim(p.width))"
            let showDims = max(pxW, pxH) >= 40 && min(pxW, pxH) >= 18
            let shortSide = min(pxW, pxH)
            let partFontSz = min(9, shortSide * 0.25)
            let dimFontSz = min(7, shortSide * 0.18)
            let vOff = showDims ? rect.height * 0.12 : 0

            context.drawLayer { layer in
                if isPortrait {
                    layer.translateBy(x: cx, y: cy)
                    layer.rotate(by: .degrees(-90))
                    layer.translateBy(x: -cx, y: -cy)
                }
                layer.draw(Text(label).font(Theme.board(partFontSz, .semibold)).foregroundStyle(Color(hex: CutPlanBoard.ink)),
                          at: CGPoint(x: cx, y: cy - vOff), anchor: .center)
                if showDims {
                    layer.draw(Text(dimLabel).font(Theme.board(dimFontSz)).foregroundStyle(Color(hex: CutPlanBoard.ink).opacity(0.55)),
                              at: CGPoint(x: cx, y: cy + vOff), anchor: .center)
                }
            }
        }

        // Outer sheet border.
        context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: CutPlanBoard.ink)), lineWidth: 2)
    }
}

extension Color {
    /// Parses a `#RRGGBB` hex string (as used by `cutPlanPalette`). Falls back
    /// to black on malformed input.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

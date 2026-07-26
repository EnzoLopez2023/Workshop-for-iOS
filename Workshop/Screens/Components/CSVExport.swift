import Foundation
import NintekKit

/// CSV file generation for the "Export" buttons on Cut List / Materials —
/// parity with the web's `exportCutListCsv`/`exportMaterialsCsv` (`ProjectDetail.tsx`),
/// writing to a temp file so it can be handed to `ActivityShareSheet` (share/
/// save/print via the standard share sheet, replacing the web's browser download).
enum CSVExport {
    static func cutListCSV(_ items: [CutListItem], projectTitle: String) -> URL? {
        var lines = ["Part,Qty,Length,Width,Thickness,Material"]
        for c in items {
            lines.append("\"\(esc(c.partName))\",\(c.qty),\"\(esc(c.length ?? ""))\",\"\(esc(c.width ?? ""))\",\"\(esc(c.thickness ?? ""))\",\"\(esc(c.material ?? ""))\"")
        }
        return write(lines.joined(separator: "\n"), filename: "\(sanitize(projectTitle))-cut-list.csv")
    }

    static func materialsCSV(_ items: [WSMaterial], projectTitle: String) -> URL? {
        var lines = ["Name,Qty,Cost,Purchased"]
        for m in items {
            lines.append("\"\(esc(m.name))\",\"\(esc(m.qtyLabel ?? ""))\",\(m.cost),\(m.purchased ? "Yes" : "No")")
        }
        return write(lines.joined(separator: "\n"), filename: "\(sanitize(projectTitle))-materials.csv")
    }

    private static func write(_ content: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func esc(_ s: String) -> String { s.replacingOccurrences(of: "\"", with: "\"\"") }
    private static func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "-", options: .regularExpression)
    }
}

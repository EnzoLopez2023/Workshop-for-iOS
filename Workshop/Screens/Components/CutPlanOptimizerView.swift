import SwiftUI
import NintekKit

/// The cut-plan optimizer — port of `CutPlanOptimizer.tsx`: an editable stock
/// panel list (with 4×8/4×10 presets), a kerf field, Generate, a stats row,
/// warning banners for skipped/unplaced pieces, sheet diagrams (up to 6 shown
/// at once, expandable), and a color legend. Config (stock rows + kerf)
/// auto-loads on appear and auto-saves after a successful Generate, via the
/// same `?cut-plan-config` endpoint the web app reads/writes — configs are
/// fully interoperable between web and native.
///
/// PDF export (the web's print-window SVG doc) is not yet ported — see
/// Phase 4.4 in the plan.
struct CutPlanOptimizerView: View {
    let api: WorkshopAPI
    let cutList: [CutListItem]
    let projectId: Int?

    @State private var stockRows: [StockRow] = [StockRow()]
    @State private var kerfStr = "0.125"
    @State private var result: CutPlanResult?
    @State private var colorMap: [String: String] = [:]
    @State private var skipped: [String] = []
    @State private var inputError: String?
    @State private var showAll = false
    @State private var hasSavedConfig = false
    @State private var exportedPDF: IdentifiableURL?
    @State private var exporting = false

    private static let presets: [(label: String, length: String, width: String)] = [
        ("+ 4×8 Sheet", "96", "48"),
        ("+ 4×10 Sheet", "120", "48"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stockPanel
            kerfAndGenerateRow
            if let inputError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 13))
                    Text(inputError).font(Theme.ui(13, .regular))
                }
                .foregroundStyle(Theme.red)
            }
            if let result { resultsSection(result) }
        }
        .task { await loadConfig() }
        .sheet(item: $exportedPDF) { ActivityShareSheet(items: [$0.url]) }
        .sensoryFeedback(.success, trigger: result) { old, new in old == nil && new != nil }
    }

    // MARK: Stock panel

    private var stockPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVAILABLE STOCK PANELS").font(Theme.ui(11, .bold)).tracking(1).foregroundStyle(Theme.muted)

            VStack(spacing: 8) {
                ForEach($stockRows) { $row in
                    stockRowEditor(row: $row)
                }
            }

            HStack(spacing: 8) {
                Button { stockRows.append(StockRow()) } label: {
                    Label("Add Row", systemImage: "plus").font(Theme.ui(13, .regular))
                }
                ForEach(Self.presets, id: \.label) { preset in
                    Button(preset.label) {
                        stockRows.append(StockRow(lengthStr: preset.length, widthStr: preset.width))
                    }
                    .font(Theme.ui(12, .regular))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.flap, in: RoundedRectangle(cornerRadius: Theme.rFlap))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rFlap).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2])).foregroundStyle(Theme.line))
                }
                if hasSavedConfig {
                    Spacer()
                    Text("✓ config loaded").font(Theme.ui(11, .regular)).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(16)
        .background(Theme.flapShade, in: RoundedRectangle(cornerRadius: 3))
    }

    private func stockRowEditor(row: Binding<StockRow>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("96", text: row.lengthStr).keyboardType(.decimalPad)
                Text("×").font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                TextField("48", text: row.widthStr).keyboardType(.decimalPad)
                TextField("3/4", text: row.thicknessStr).frame(width: 60)
            }
            HStack(spacing: 8) {
                TextField("1", text: row.qtyStr).keyboardType(.numberPad).frame(width: 44)
                TextField("Label (optional)", text: row.label)
                Button {
                    stockRows.removeAll { $0.id == row.wrappedValue.id }
                } label: {
                    Image(systemName: "trash").font(.system(size: 13))
                        .foregroundStyle(stockRows.count == 1 ? Theme.line : Theme.muted)
                }
                .disabled(stockRows.count == 1)
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(Theme.ui(13, .regular))
        .padding(10)
        .background(Theme.flap, in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
    }

    // MARK: Kerf + generate

    private var kerfAndGenerateRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("Saw Kerf").font(Theme.ui(13, .medium)).foregroundStyle(Theme.muted)
                TextField("0.125", text: $kerfStr).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 70)
                Text("inches").font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if projectId != nil {
                Button { Task { await saveConfig() } } label: {
                    Label("Save Config", systemImage: "square.and.arrow.down").font(Theme.ui(13, .regular))
                }
            }
            Button { generate() } label: {
                Label("Generate Cut Plan", systemImage: "scissors")
                    .font(Theme.ui(14, .medium))
                    .padding(.horizontal, 14).padding(.vertical, 9)
            }
            .background(Theme.steel, in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(Theme.concourse)
            .buttonStyle(.plain)
        }
    }

    // MARK: Results

    @ViewBuilder private func resultsSection(_ result: CutPlanResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                PlanStat(label: "Sheets Used", value: "\(result.totalSheets)")
                PlanStat(label: "Overall Yield", value: String(format: "%.1f%%", result.overallYieldPercent))
                PlanStat(label: "Pieces Placed", value: "\(result.layouts.reduce(0) { $0 + $1.placed.count })")
                PlanStat(label: "Total Cuts", value: "\(result.totalCuts)")
            }
            .padding(.bottom, 16)
            .overlay(alignment: .bottom) { Divider().overlay(Theme.line) }

            if !skipped.isEmpty {
                banner(color: Theme.accent, bg: Theme.tint(Theme.accentFill), icon: "exclamationmark.triangle") {
                    "\(skipped.count) piece\(skipped.count == 1 ? "" : "s") skipped (missing dimensions): \(orderedUniqueJoin(skipped))"
                }
            }
            if !result.unplacedPieces.isEmpty {
                banner(color: Theme.red, bg: Theme.tint(Theme.red), icon: "exclamationmark.circle") {
                    "\(result.unplacedPieces.count) piece\(result.unplacedPieces.count == 1 ? "" : "s") could not be placed (too large or no matching stock): \(result.unplacedPieces.joined(separator: ", "))"
                }
            }

            Button {
                exportPDF(result)
            } label: {
                Label(exporting ? "Preparing…" : "Download PDF", systemImage: "square.and.arrow.down")
                    .font(Theme.ui(13, .regular))
            }
            .disabled(exporting)

            VStack(spacing: 20) {
                ForEach(visibleLayouts(result), id: \.sheetIndex) { layout in
                    CutPlanSheetView(layout: layout, sheetNumber: layout.sheetIndex + 1, totalSheets: result.totalSheets,
                                     colorMap: colorMap, stockLabel: formatStockLabel(stockRow(for: layout.stockId)))
                        .padding(16)
                        .background(Theme.flap, in: RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
                }
            }

            if result.layouts.count > 6 {
                Button(showAll ? "Show fewer sheets" : "Show all \(result.layouts.count) sheets") {
                    showAll.toggle()
                }
                .font(Theme.ui(13, .regular))
            }

            if !colorMap.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LEGEND").font(Theme.ui(11, .bold)).tracking(1).foregroundStyle(Theme.muted)
                    FlowLayout(spacing: 14) {
                        ForEach(colorMap.sorted(by: { $0.key < $1.key }), id: \.key) { name, hex in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2).fill(Color(hex: hex)).frame(width: 14, height: 14)
                                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.1), lineWidth: 1))
                                Text(name).font(Theme.ui(13, .regular)).foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }
                .padding(.top, 16)
                .overlay(alignment: .top) { Divider().overlay(Theme.line) }
            }
        }
    }

    private func banner(color: Color, bg: Color, icon: String, text: () -> String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).padding(.top, 1)
            Text(text()).font(Theme.ui(13, .regular))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(bg, in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color, lineWidth: 1))
    }

    private func visibleLayouts(_ result: CutPlanResult) -> [SheetLayout] {
        showAll ? result.layouts : Array(result.layouts.prefix(6))
    }

    // MARK: Helpers

    private func stockRow(for stockId: String) -> StockRow? {
        stockRows.first { $0.id == stockId }
    }

    /// Mirrors the web's `formatStockLabel`: thickness gets a trailing `"`
    /// unless it already ends in one, then joins with the label.
    private func formatStockLabel(_ row: StockRow?) -> String? {
        guard let row else { return nil }
        let t = row.thicknessStr.trimmingCharacters(in: .whitespaces)
        let l = row.label.trimmingCharacters(in: .whitespaces)
        let endsWithQuote = t.range(of: "[\"\u{201D}\u{201C}]\\s*$", options: .regularExpression) != nil
        let thickPart = t.isEmpty ? "" : (endsWithQuote ? t : "\(t)\"")
        let combined = [thickPart, l].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }

    private func orderedUniqueJoin(_ items: [String]) -> String {
        var seen = Set<String>()
        var result: [String] = []
        for item in items where !seen.contains(item) { seen.insert(item); result.append(item) }
        return result.joined(separator: ", ")
    }

    // MARK: Actions

    private func generate() {
        inputError = nil
        var stocks: [StockSheet] = []
        for row in stockRows {
            guard let l = parseInches(row.lengthStr), let w = parseInches(row.widthStr),
                  let qty = Int(row.qtyStr), qty >= 1 else {
                inputError = "One or more stock rows have invalid dimensions or quantity."
                return
            }
            stocks.append(StockSheet(id: row.id, length: l, width: w, qty: qty,
                                     label: row.label.trimmingCharacters(in: .whitespaces),
                                     thickness: row.thicknessStr.trimmingCharacters(in: .whitespaces)))
        }
        guard let kerf = Double(kerfStr), kerf >= 0 else {
            inputError = "Kerf must be a non-negative number."
            return
        }

        let (pieces, sk) = buildCutPieces(cutList)
        skipped = sk
        guard !pieces.isEmpty else {
            inputError = "No placeable pieces in the cut list — check that all pieces have valid length and width dimensions."
            return
        }

        let res = optimizeCuts(stocks: stocks, pieces: pieces, kerf: kerf)
        colorMap = CutPlanBoard.colorMap(res.layouts)
        result = res
        showAll = false

        if let projectId {
            Task {
                try? await api.saveCutPlanConfig(projectId: projectId, CutPlanConfig(stockRows: stockRows, kerfStr: kerfStr))
                hasSavedConfig = true
            }
        }
    }

    private func loadConfig() async {
        guard let projectId else { return }
        do {
            if let config = try await api.cutPlanConfig(projectId: projectId) {
                if !config.stockRows.isEmpty { stockRows = config.stockRows; hasSavedConfig = true }
                kerfStr = config.kerfStr
            }
        } catch { /* no config saved yet — matches the web's silent .catch */ }
    }

    private func saveConfig() async {
        guard let projectId else { return }
        do {
            try await api.saveCutPlanConfig(projectId: projectId, CutPlanConfig(stockRows: stockRows, kerfStr: kerfStr))
            hasSavedConfig = true
        } catch { /* best-effort, matches the web */ }
    }

    private func exportPDF(_ result: CutPlanResult) {
        exporting = true
        if let url = CutPlanPDFExporter.export(result: result, colorMap: colorMap,
                                               stockLabel: { formatStockLabel(stockRow(for: $0)) }) {
            exportedPDF = IdentifiableURL(url: url)
        }
        exporting = false
    }
}

private struct PlanStat: View {
    let label: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(Theme.ui(10, .medium)).tracking(0.5).foregroundStyle(Theme.muted)
            Text(value).font(Theme.ui(20, .bold)).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

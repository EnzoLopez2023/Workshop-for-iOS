import SwiftUI

/// Pure-Swift port of `ConversionTables.tsx` — no API calls. A live mm↔inch
/// quick converter plus three reference tables (MM→Inches, Inches→MM,
/// Fractional→MM). Math ported verbatim (gcd-reduced fractions, nearest 1/32").
///
/// The web's Fractional→MM table is an 8-column grid (one column per eighth,
/// one row per whole inch) — that doesn't fit a phone width, so it's adapted
/// here to a whole-inch section list with its 8 eighths wrapped as chips
/// below each header. Same 384 data points, mobile-appropriate layout.
struct ConversionTablesView: View {
    @State private var inputText = ""
    @State private var unit: ConvUnit = .mm
    @State private var tab: ConvTab = .mmToIn

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    quickConverter
                    tabPicker
                    switch tab {
                    case .mmToIn: mmToInTable
                    case .inToMm: inToMmTable
                    case .fracToMm: fracToMmTable
                    }
                }
                .contentColumn(700)
                .padding(20)
            }
            .creamBackground()
            .navigationTitle("Tables")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.cream)
                .frame(width: 36, height: 36)
                .background(Theme.inkSoft, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("Unit Conversions").font(Theme.display(21)).foregroundStyle(Theme.ink)
                Text("MM ↔ Inches reference tables and on-the-fly calculator")
                    .font(.system(size: 12)).foregroundStyle(Theme.subtle)
            }
        }
    }

    // MARK: Quick converter

    private var num: Double { Double(inputText) ?? 0 }
    private var mmVal: Double { unit == .mm ? num : num * 25.4 }
    private var inVal: Double { unit == .in ? num : num / 25.4 }
    private var hasVal: Bool { num > 0 }

    private var quickConverter: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QUICK CONVERTER").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(Theme.subtle)
            HStack(spacing: 12) {
                TextField("Enter a value…", text: $inputText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.creamSoft, in: RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: 160)
                HStack(spacing: 6) {
                    unitButton("mm", .mm)
                    unitButton("in", .in)
                }
            }
            if hasVal {
                HStack(spacing: 28) {
                    resultPill("Millimeters", String(format: "%.3f mm", mmVal), accent: false)
                    resultPill("Decimal Inches", String(format: "%.5f\"", inVal), accent: false)
                    resultPill("Nearest 1/32\"", toFrac32(inVal), accent: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func unitButton(_ label: String, _ u: ConvUnit) -> some View {
        let active = unit == u
        return Button { unit = u } label: {
            Text(label).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                .foregroundStyle(active ? Theme.cream : Theme.ink)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(active ? Theme.inkSoft : Theme.creamSoft, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func resultPill(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Theme.subtle)
            Text(value).font(accent ? Theme.display(20) : .system(size: 20, weight: .bold))
                .foregroundStyle(accent ? Theme.accent : Theme.ink)
        }
    }

    // MARK: Tabs

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ConvTab.allCases) { t in
                    let active = tab == t
                    Button { tab = t } label: {
                        Text(t.label).font(.system(size: 13, weight: .medium))
                            .foregroundStyle(active ? Theme.cream : Theme.ink)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(active ? Theme.inkSoft : Theme.creamSoft, in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: MM → Inches

    private var mmToInTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            note("1 – 100 mm converted to decimal and fractional inches (nearest 1/32\")")
            VStack(spacing: 0) {
                tableHeader(["MM", "Decimal Inches", "Nearest 1/32\""])
                ForEach(Self.mmTable, id: \.mm) { row in
                    rowDivider
                    HStack {
                        cell("\(row.mm) mm", weight: .regular, color: Theme.ink)
                        Spacer()
                        cell(String(format: "%.5f\"", row.dec), weight: .regular, color: Theme.subtle)
                        Spacer()
                        cell(row.frac, weight: .semibold, color: Theme.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(row.mm.isMultiple(of: 2) ? Theme.creamSoft : Color.clear)
                }
            }
            .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Inches → MM

    private var inToMmTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            note("1\" – 96\" whole inches converted to millimeters (1\" = 25.4 mm exactly)")
            VStack(spacing: 0) {
                tableHeader(["Inches", "Millimeters"])
                ForEach(Self.inTable, id: \.inches) { row in
                    rowDivider
                    HStack {
                        cell("\(row.inches)\"", weight: .regular, color: Theme.ink)
                        Spacer()
                        cell(String(format: "%.1f mm", row.mm), weight: .semibold, color: Theme.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(row.inches.isMultiple(of: 2) ? Theme.creamSoft : Color.clear)
                }
            }
            .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Fractional → MM (mobile adaptation: grouped by whole inch)

    private var fracToMmTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            note("1/8\" increments from 1/8\" to 48\" — grouped by whole inch")
            VStack(spacing: 0) {
                ForEach(Array(Self.fracGroups.enumerated()), id: \.offset) { wholeIdx, group in
                    if wholeIdx > 0 { rowDivider }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(wholeIdx + 1)\"").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.subtle)
                        FlowLayout(spacing: 8) {
                            ForEach(group, id: \.label) { cell in
                                HStack(spacing: 4) {
                                    Text(cell.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text("\(cell.mm, specifier: "%.3g") mm").font(.system(size: 11)).foregroundStyle(Theme.subtle)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.creamSoft, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(wholeIdx.isMultiple(of: 2) ? Theme.creamSoft.opacity(0.4) : Color.clear)
                }
            }
            .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Shared table pieces

    private func tableHeader(_ titles: [String]) -> some View {
        HStack {
            ForEach(titles, id: \.self) { t in
                Text(t.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(Theme.subtle)
                if t != titles.last { Spacer() }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.creamSoft)
    }
    private var rowDivider: some View { Divider().overlay(Theme.line) }
    private func cell(_ t: String, weight: Font.Weight, color: Color) -> some View {
        Text(t).font(.system(size: 14, weight: weight)).foregroundStyle(color)
    }
    private func note(_ t: String) -> some View {
        Text(t).font(.system(size: 12)).foregroundStyle(Theme.subtle)
    }

    // MARK: Precomputed tables (ported verbatim from ConversionTables.tsx)

    private static let mmTable: [(mm: Int, dec: Double, frac: String)] = (1...100).map { mm in
        let dec = Double(mm) / 25.4
        return (mm, dec, toFrac32(dec))
    }

    private static let inTable: [(inches: Int, mm: Double)] = (1...96).map { ($0, Double($0) * 25.4) }

    private struct FracCell { let label: String; let mm: Double }
    /// 48 groups (whole inches) × 8 eighths each.
    private static let fracGroups: [[FracCell]] = (0..<48).map { whole in
        (0..<8).map { eighth in
            let eighths = whole * 8 + eighth + 1
            let mm = (Double(eighths) / 8 * 25.4 * 1000).rounded() / 1000
            return FracCell(label: toFrac8Label(eighths), mm: mm)
        }
    }
}

// MARK: - Types + math helpers (verbatim port of the web's gcd/toFrac32/toFrac8Label)

private enum ConvUnit { case mm, `in` }

private enum ConvTab: String, CaseIterable, Identifiable {
    case mmToIn, inToMm, fracToMm
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mmToIn: "MM → Inches"
        case .inToMm: "Inches → MM"
        case .fracToMm: "Fractional → MM"
        }
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

/// Nearest 1/32" fractional label for a decimal-inches value.
private func toFrac32(_ inches: Double) -> String {
    if inches <= 0 { return "0\"" }
    let whole = Int(inches.rounded(.down))
    let frac = inches - Double(whole)
    var n = Int((frac * 32).rounded())
    if n >= 32 { return "\(whole + 1)\"" }
    if n == 0 { return "\(whole)\"" }
    let g = gcd(n, 32)
    let num = n / g, den = 32 / g
    n = num
    return whole > 0 ? "\(whole) \(num)/\(den)\"" : "\(num)/\(den)\""
}

/// Fractional label (reduced eighths) for a count of eighths of an inch.
private func toFrac8Label(_ eighths: Int) -> String {
    let whole = eighths / 8
    let rem = eighths % 8
    if rem == 0 { return "\(whole)\"" }
    let g = gcd(rem, 8)
    let num = rem / g, den = 8 / g
    return whole > 0 ? "\(whole) \(num)/\(den)\"" : "\(num)/\(den)\""
}

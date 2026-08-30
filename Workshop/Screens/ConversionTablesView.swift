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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            .planBackground()
            .navigationTitle("Tables")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.action)
                .frame(width: 40, height: 40)
                .background(
                    Theme.tint(Theme.annotation),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Unit Conversions")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("MM ↔ Inches reference tables and on-the-fly calculator")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Quick converter

    private var num: Double { Double(inputText).flatMap { $0.isFinite ? $0 : nil } ?? 0 }
    private var mmVal: Double { unit == .mm ? num : num * 25.4 }
    private var inVal: Double { unit == .in ? num : num / 25.4 }
    private var hasVal: Bool { num > 0 }

    private var quickConverter: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Converter")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                TextField("Enter a value…", text: $inputText)
                    .keyboardType(.decimalPad)
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        Theme.recessed,
                        in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    )
                    .frame(maxWidth: 160)
                Picker("Input unit", selection: $unit) {
                    Text("mm").tag(ConvUnit.mm)
                    Text("in").tag(ConvUnit.in)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 160)
            }
            if hasVal {
                conversionResultsLayout {
                    resultPill("Millimeters", String(format: "%.3f mm", mmVal), accent: false)
                    resultPill("Decimal Inches", String(format: "%.5f\"", inVal), accent: false)
                    resultPill("Nearest 1/32\"", toFrac32(inVal), accent: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .planGlass()
    }

    private var conversionResultsLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        } else {
            AnyLayout(HStackLayout(spacing: 28))
        }
    }

    private func resultPill(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(accent ? Theme.action : Theme.ink)
        }
    }

    // MARK: Tabs

    private var tabPicker: some View {
        Picker("Reference table", selection: $tab) {
            ForEach(ConvTab.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
                        cell(String(format: "%.5f\"", row.dec), weight: .regular, color: Theme.muted)
                        Spacer()
                        cell(row.frac, weight: .semibold, color: Theme.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(row.mm.isMultiple(of: 2) ? Theme.recessed : Color.clear)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    .strokeBorder(Theme.divider.opacity(0.62), lineWidth: 1)
            )
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
                    .background(row.inches.isMultiple(of: 2) ? Theme.recessed : Color.clear)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    .strokeBorder(Theme.divider.opacity(0.62), lineWidth: 1)
            )
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
                        Text("\(wholeIdx + 1)\"")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        FlowLayout(spacing: 8) {
                            ForEach(group, id: \.label) { cell in
                                HStack(spacing: 4) {
                                    Text(cell.label)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.ink)
                                    Text("\(cell.mm, specifier: "%.3g") mm")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(
                                    Theme.recessed,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(wholeIdx.isMultiple(of: 2) ? Theme.recessed.opacity(0.4) : Color.clear)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    .strokeBorder(Theme.divider.opacity(0.62), lineWidth: 1)
            )
        }
    }

    // MARK: Shared table pieces

    private func tableHeader(_ titles: [String]) -> some View {
        HStack {
            ForEach(titles, id: \.self) { t in
                Text(t)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                if t != titles.last { Spacer() }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.recessed)
    }
    private var rowDivider: some View { Divider().overlay(Theme.divider) }
    private func cell(_ t: String, weight: Font.Weight, color: Color) -> some View {
        Text(t)
            .font(.system(.subheadline, design: .rounded, weight: weight))
            .monospacedDigit()
            .foregroundStyle(color)
    }
    private func note(_ t: String) -> some View {
        Text(t).font(.caption).foregroundStyle(Theme.muted)
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
    // `Int(_:)` traps on infinity, NaN, and anything past Int64 — and this is
    // fed straight from a text field, where holding down "9" reaches 1e22 in a
    // couple of seconds. Screen the value before converting, not after.
    guard inches.isFinite, inches > 0 else { return "0\"" }
    guard inches < 1e9 else { return "—" }
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

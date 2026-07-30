import SwiftUI
import Charts
import NintekKit

/// Analytics the web app doesn't have at all (Phase 7.6) — spend over time,
/// materials cost by project, and build-log activity, all derived from data
/// already loaded elsewhere (no new endpoints).
struct InsightsView: View {
    let api: WorkshopAPI

    @State private var projects: [WSProject] = []
    @State private var buildLogEntries: [BuildLogEntry] = []
    @State private var loading = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                } else if let err = loadError {
                    errorState(err)
                } else if projects.isEmpty {
                    Text("No projects yet — insights will show up once you have some.")
                        .font(Theme.ui(14, .regular)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity).padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 36) {
                        spendOverTimeSection
                        costByProjectSection
                        buildActivitySection
                    }
                    .contentColumn(900)
                    .padding(20)
                }
            }
            .boardBackground()
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: Spend over time

    private var spendOverTimeSection: some View {
        let points = cumulativeSpend()
        return VStack(alignment: .leading, spacing: 12) {
            Rail("Spend Over Time")
            if points.isEmpty {
                Text("No materials cost logged yet.").font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
            } else {
                Chart(points, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Cumulative Cost", point.cumulative))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Date", point.date), y: .value("Cumulative Cost", point.cumulative))
                        .foregroundStyle(Theme.accent.opacity(0.15))
                        .interpolationMethod(.monotone)
                }
                .chartYAxis { AxisMarks { value in
                    AxisValueLabel { if let v = value.as(Double.self) { Text(money(v)) } }
                    AxisGridLine()
                } }
                .frame(height: 200)
            }
        }
    }

    // MARK: Cost by project

    private var costByProjectSection: some View {
        let rows = projects
            .filter { ($0.totalCost ?? 0) > 0 }
            .sorted { ($0.totalCost ?? 0) > ($1.totalCost ?? 0) }
            .prefix(8)
        return VStack(alignment: .leading, spacing: 12) {
            Rail("Materials Cost by Project")
            if rows.isEmpty {
                Text("No materials cost logged yet.").font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
            } else {
                Chart(rows) { p in
                    BarMark(x: .value("Cost", p.totalCost ?? 0), y: .value("Project", p.title))
                        .foregroundStyle(Theme.accent)
                        .annotation(position: .trailing) { Text(money(p.totalCost ?? 0)).font(Theme.ui(11, .regular)).foregroundStyle(Theme.muted) }
                }
                .frame(height: CGFloat(rows.count) * 34 + 20)
            }
        }
    }

    // MARK: Build activity

    private var buildActivitySection: some View {
        let months = buildActivityByMonth()
        return VStack(alignment: .leading, spacing: 12) {
            Rail("Build Log Activity")
            if months.isEmpty {
                Text("No build-log entries yet — every note and photo you add in the shop shows up here.")
                    .font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
            } else {
                Chart(months, id: \.month) { row in
                    BarMark(x: .value("Month", row.month, unit: .month), y: .value("Entries", row.count))
                        .foregroundStyle(Theme.accent)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                .frame(height: 180)
                Text("\(buildLogEntries.count) build-log entr\(buildLogEntries.count == 1 ? "y" : "ies") across \(projects.filter { ($0.partsCount ?? 0) > 0 }.count) projects with a cut list.")
                    .font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load insights").font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(Theme.ink)
            Text(msg).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.muted)
            Button("Retry") { Task { await load() } }
        }.frame(maxWidth: .infinity).padding(.top, 80)
    }

    // MARK: Data shaping

    private struct SpendPoint { let date: Date; let cumulative: Double }

    private func cumulativeSpend() -> [SpendPoint] {
        let dated = projects.compactMap { p -> (Date, Double)? in
            guard let date = parseDate(p.createdAt), let cost = p.totalCost, cost > 0 else { return nil }
            return (date, cost)
        }.sorted { $0.0 < $1.0 }
        var running = 0.0
        return dated.map { date, cost in running += cost; return SpendPoint(date: date, cumulative: running) }
    }

    private struct MonthActivity { let month: Date; let count: Int }

    private func buildActivityByMonth() -> [MonthActivity] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for entry in buildLogEntries {
            guard let date = parseDate(entry.createdAt) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let monthStart = calendar.date(from: comps) else { continue }
            counts[monthStart, default: 0] += 1
        }
        return counts.map { MonthActivity(month: $0.key, count: $0.value) }.sorted { $0.month < $1.month }
    }

    private func parseDate(_ raw: String) -> Date? {
        Self.ymdParser.date(from: String(raw.prefix(10)))
    }

    private static let ymdParser: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    private func money(_ n: Double) -> String { String(format: "$%.0f", n) }

    // MARK: Load

    private func load() async {
        loading = projects.isEmpty
        loadError = nil
        do {
            projects = try await api.listProjects()
            // Build-log entries live on the per-project detail payload — fetch
            // every project's detail concurrently (fine at personal-project scale).
            buildLogEntries = try await withThrowingTaskGroup(of: [BuildLogEntry].self) { group in
                for p in projects { group.addTask { (try? await api.project(id: p.id))?.buildLog ?? [] } }
                var all: [BuildLogEntry] = []
                for try await entries in group { all.append(contentsOf: entries) }
                return all
            }
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }
}

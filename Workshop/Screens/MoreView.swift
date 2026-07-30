import SwiftUI
import UserNotifications
import NintekKit

/// Settings tab — parity with the web's `Settings.tsx`: appearance (theme,
/// accent, text size), project defaults (default status, dashboard sort,
/// show-completed), data export (JSON backup), signed-in identity + sign out,
/// and version footer.
struct MoreView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeManager

    @AppStorage("ws.appearance") private var appearanceRaw = Appearance.system.rawValue
    @AppStorage("ws.fontSizeLarge") private var fontSizeLarge = false
    @AppStorage(SettingsKeys.defaultProjectStatus) private var defaultStatusRaw = ProjectStatus.idea.rawValue
    @AppStorage(SettingsKeys.dashboardSort) private var dashboardSortRaw = DashboardSort.updated.rawValue
    @AppStorage(SettingsKeys.showCompletedByDefault) private var showCompletedByDefault = false

    @State private var exporting = false
    @State private var exportError: String?
    @State private var exportURL: IdentifiableURL?

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(Appearance.allCases) { a in Text(a.label).tag(a) }
                    }
                    Picker("Accent", selection: Binding(
                        get: { theme.selection },
                        set: { theme.selection = $0 }
                    )) {
                        ForEach(Palette.all) { p in Text(p.name).tag(p.id) }
                    }
                    Toggle("Large Text", isOn: $fontSizeLarge)
                }

                Section {
                    Picker("Default Status", selection: defaultStatusBinding) {
                        Text(ProjectStatus.idea.label).tag(ProjectStatus.idea)
                        Text(ProjectStatus.planning.label).tag(ProjectStatus.planning)
                        Text(ProjectStatus.inProgress.label).tag(ProjectStatus.inProgress)
                    }
                    Picker("Dashboard Sort", selection: dashboardSortBinding) {
                        ForEach(DashboardSort.allCases) { s in Text(s.label).tag(s) }
                    }
                    Toggle("Show Completed by Default", isOn: $showCompletedByDefault)
                } header: {
                    Text("Projects")
                }

                Section {
                    NavigationLink {
                        InsightsView(api: api)
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                }

                Section {
                    Button {
                        Task { await exportBackup() }
                    } label: {
                        Label(exporting ? "Preparing…" : "Export JSON Backup", systemImage: "square.and.arrow.down")
                    }
                    .disabled(exporting)
                    if let exportError {
                        Text(exportError).font(.footnote).foregroundStyle(Theme.fail)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Downloads all your projects and their metadata as a JSON file.")
                }

                Section("DEBUG") {
                    Button("Test finish reminder scheduling") {
                        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                        let json = """
                        {"id": 999999, "product_name": "Debug Test Finish", "coats": 2, "applied_at": "\(df.string(from: Date()))"}
                        """.data(using: .utf8)!
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        guard let entry = try? decoder.decode(FinishLogEntry.self, from: json) else {
                            NSLog("[Workshop][DEBUG] failed to decode test entry")
                            return
                        }
                        FinishReminderScheduler.requestAuthorizationIfNeeded()
                        FinishReminderScheduler.schedule(entry, projectTitle: "Debug Project")
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            let mine = requests.filter { $0.identifier == "finish-reminder-999999" }
                            NSLog("[Workshop][DEBUG] pending total=%d mine=%d", requests.count, mine.count)
                            if let req = mine.first, let trigger = req.trigger as? UNCalendarNotificationTrigger,
                               let fireDate = trigger.nextTriggerDate() {
                                NSLog("[Workshop][DEBUG] scheduled fire date: %@", fireDate.description)
                            }
                        }
                    }
                }
                Section("Account") {
                    if let name = model.userName {
                        LabeledContent("Signed in as", value: name)
                    }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                }
                Section {
                    LabeledContent("Version", value: AppInfo.version)
                }
            }
            .navigationTitle("More")
            .sheet(item: $exportURL) { ActivityShareSheet(items: [$0.url]) }
        }
    }

    private var appearanceBinding: Binding<Appearance> {
        Binding(get: { Appearance(rawValue: appearanceRaw) ?? .system },
               set: { appearanceRaw = $0.rawValue })
    }
    private var defaultStatusBinding: Binding<ProjectStatus> {
        Binding(get: { ProjectStatus(rawValue: defaultStatusRaw) ?? .idea },
               set: { defaultStatusRaw = $0.rawValue })
    }
    private var dashboardSortBinding: Binding<DashboardSort> {
        Binding(get: { DashboardSort(rawValue: dashboardSortRaw) ?? .updated },
               set: { dashboardSortRaw = $0.rawValue })
    }

    // MARK: Export

    private func exportBackup() async {
        exporting = true; exportError = nil
        do {
            let projects = try await api.listProjects()
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projects)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("workshop-backup-\(df.string(from: Date())).json")
            try data.write(to: url)
            exportURL = IdentifiableURL(url: url)
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }
        exporting = false
    }
}

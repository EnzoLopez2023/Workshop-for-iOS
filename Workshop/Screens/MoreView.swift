import SwiftUI
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
                Section(header: BoardCaps("Appearance")) {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(Appearance.allCases) { a in Text(a.label).tag(a) }
                    }
                    lampPicker
                    Toggle("Large Text", isOn: $fontSizeLarge)
                        .toggleStyle(.flap)
                }
                .listRowBackground(Theme.flap)
                .listRowSeparatorTint(Theme.line)

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
                        .toggleStyle(.flap)
                } header: {
                    BoardCaps("Projects")
                }
                .listRowBackground(Theme.flap)
                .listRowSeparatorTint(Theme.line)

                Section {
                    NavigationLink {
                        InsightsView(api: api)
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                }
                .listRowBackground(Theme.flap)
                .listRowSeparatorTint(Theme.line)

                Section {
                    Button {
                        Task { await exportBackup() }
                    } label: {
                        Label(exporting ? "Preparing…" : "Export JSON Backup", systemImage: "square.and.arrow.down")
                    }
                    .disabled(exporting)
                    if let exportError {
                        Text(exportError).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.red)
                    }
                } header: {
                    BoardCaps("Data")
                } footer: {
                    Text("Downloads all your projects and their metadata as a JSON file.")
                }
                .listRowBackground(Theme.flap)
                .listRowSeparatorTint(Theme.line)

                Section(header: BoardCaps("Account")) {
                    if let name = model.userName {
                        LabeledContent("Signed in as", value: name)
                    }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                }
                .listRowBackground(Theme.flap)
                .listRowSeparatorTint(Theme.line)
                Section {
                    LabeledContent("Version", value: AppInfo.version)
                }
                .listRowBackground(Theme.flap)
                .listRowSeparatorTint(Theme.line)
            }
            // The system inset-grouped list draws pure-white rows on a 20pt
            // radius; the board has neither. Flap faces on the concourse, with
            // the frame drawn by the row separators.
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.concourse)
            .environment(\.defaultMinListRowHeight, 46)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $exportURL) { ActivityShareSheet(items: [$0.url]) }
        }
    }

    /// The signal lamps, shown lit rather than named. Picking an accent by
    /// reading the word "Amber" is worse than picking it by seeing amber, and
    /// the lamp is the one place this app spends colour.
    private var lampPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Signal Lamp")
                Spacer()
                Text((Palette.all.first { $0.id == theme.selection }?.name ?? "").uppercased())
                    .font(Theme.board(9.5, .semibold, relativeTo: .caption2))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                ForEach(Palette.all) { p in
                    let on = p.id == theme.selection
                    Button { theme.selection = p.id } label: {
                        // A lamp behind glass, not a paint chip: the dark flap
                        // face stays, the colour is the light coming through it.
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.rFlap)
                                .fill(Theme.flapFaceGradient)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(p.accentFill.color)
                                .frame(height: 10)
                                .padding(.horizontal, 9)
                                .shadow(color: p.accentFill.color.opacity(on ? 0.85 : 0),
                                        radius: 5)
                                .opacity(on ? 1 : 0.4)
                            Rectangle()
                                .fill(Color.black.opacity(0.55))
                                .frame(height: 1)
                        }
                        .frame(height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rFlap)
                                .strokeBorder(on ? Theme.ink : Color.black.opacity(0.35),
                                              lineWidth: on ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(p.name)
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(.vertical, 4)
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

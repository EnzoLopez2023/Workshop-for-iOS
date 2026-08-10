import SwiftUI
import NintekKit

/// Settings tab — parity with the web's `Settings.tsx`: appearance (theme,
/// accent, text size), project defaults (default status, dashboard sort,
/// show-completed), data export (JSON backup), signed-in identity + sign out,
/// permanent account deletion, and version footer.
struct MoreView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeManager

    @AppStorage("ws.appearance") private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(SettingsKeys.textSize) private var textSizeRaw = TextSize.standard.rawValue
    @AppStorage(SettingsKeys.defaultProjectStatus) private var defaultStatusRaw = ProjectStatus.idea.rawValue
    @AppStorage(SettingsKeys.dashboardSort) private var dashboardSortRaw = DashboardSort.updated.rawValue
    @AppStorage(SettingsKeys.showCompletedByDefault) private var showCompletedByDefault = false

    @State private var exporting = false
    @State private var exportError: String?
    @State private var exportURL: IdentifiableURL?
    @State private var showingDeleteAccountConfirmation = false
    @State private var deletingAccount = false
    @State private var accountDeletionError: String?

    var body: some View {
        NavigationStack {
            List {
                Section(header: BoardCaps("Appearance")) {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(Appearance.allCases) { a in Text(a.label).tag(a) }
                    }
                    lampPicker
                    textSizePicker
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

                Section {
                    if let name = model.userName {
                        LabeledContent("Signed in as", value: name)
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await model.signOut() }
                    }
                        .disabled(deletingAccount)
                    Button(role: .destructive) {
                        showingDeleteAccountConfirmation = true
                    } label: {
                        if deletingAccount {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Theme.red)
                                Text("Deleting Account…")
                                    .foregroundStyle(Theme.red)
                            }
                        } else {
                            Label("Delete Account", systemImage: "trash")
                                .foregroundStyle(Theme.red)
                        }
                    }
                    .disabled(deletingAccount)
                    if let accountDeletionError {
                        Text(accountDeletionError)
                            .font(Theme.ui(13, .regular, relativeTo: .footnote))
                            .foregroundStyle(Theme.red)
                    }
                } header: {
                    BoardCaps("Account")
                } footer: {
                    Text("Delete Account permanently removes your Workshop projects, photos, lists, and account data. Export a backup first if you want to keep a copy.")
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
            .alert("Permanently Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("All projects, photos, cut lists, materials, Shaper projects, templates, and account data will be permanently deleted. This cannot be undone.")
            }
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

    /// Text size as five flap cells, each showing the letter at the size it
    /// sets. The old control was a switch labelled "Large Text", which asked
    /// the user to imagine the result; this shows it, the same way the lamp row
    /// above shows colour instead of naming it.
    private var textSizePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Text Size")
                Spacer()
                Text("\(selectedTextSize.rawValue) OF \(TextSize.allCases.count)")
                    .font(Theme.board(9.5, .semibold, relativeTo: .caption2))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                ForEach(TextSize.allCases) { size in
                    let on = size == selectedTextSize
                    Button { textSizeRaw = size.rawValue } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.rFlap)
                                .fill(Theme.flapFaceGradient)
                            // Fixed, not Dynamic-Type-relative: the sample has
                            // to hold still while it's being chosen, or every
                            // cell restates the size that's already selected.
                            Text("A")
                                .font(Theme.boardFixed(size.sampleSize, .bold))
                                .foregroundStyle(on ? Theme.accentFill : Theme.flapLetter.opacity(0.6))
                            Rectangle()
                                .fill(Color.black.opacity(0.55))
                                .frame(height: 1)
                        }
                        .frame(height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rFlap)
                                .strokeBorder(on ? Theme.ink : Color.black.opacity(0.35),
                                              lineWidth: on ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Text size \(size.rawValue) of \(TextSize.allCases.count)")
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var selectedTextSize: TextSize { TextSize(rawValue: textSizeRaw) ?? .standard }

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

    private func deleteAccount() async {
        deletingAccount = true
        accountDeletionError = nil
        defer { deletingAccount = false }

        do {
            try await model.deleteAccount()
            Haptics.success()
        } catch {
            NSLog("[Workshop] Account deletion failed: %@", String(describing: error))
            Haptics.error()
            if let apiError = error as? APIError, apiError.isUnauthorized {
                accountDeletionError = "Your session expired before deletion could be confirmed. Sign out, sign back in, and try again."
            } else {
                accountDeletionError = "We couldn't delete your account. Your Workshop data remains available. Check your connection and try again."
            }
        }
    }
}

import SwiftUI
import NintekKit

private enum WorkshopLinks {
    static let support = URL(string: "https://www.nintek.com/workshop/support")!
    static let privacy = URL(string: "https://www.nintek.com/workshop/privacy")!
    static let terms = URL(string: "https://www.nintek.com/terms")!
}

/// Settings tab — parity with the web's `Settings.tsx`: appearance (theme,
/// accent, text size), project defaults (default status, dashboard sort,
/// show-completed), project-summary export, signed-in identity + sign out,
/// permanent account deletion, and version footer.
struct MoreView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeManager

    @AppStorage("ws.appearance") private var appearanceRaw = Appearance.system.rawValue
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
                Section("Appearance") {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(Appearance.allCases) { a in Text(a.label).tag(a) }
                    }
                    annotationPicker
                    LabeledContent("Text Size", value: "Follows iOS Settings")
                }
                .listRowBackground(Theme.raised.opacity(0.72))
                .listRowSeparatorTint(Theme.divider)

                if !model.isDemoMode {
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
                            .toggleStyle(.switch)
                            .tint(Theme.action)
                    } header: {
                        Text("Projects")
                    }
                    .listRowBackground(Theme.raised.opacity(0.72))
                    .listRowSeparatorTint(Theme.divider)
                }

                Section {
                    NavigationLink {
                        InsightsView(api: api)
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                }
                .listRowBackground(Theme.raised.opacity(0.72))
                .listRowSeparatorTint(Theme.divider)

                Section {
                    Button {
                        Task { await exportProjectSummary() }
                    } label: {
                        Label(exporting ? "Preparing…" : "Export Project Summary", systemImage: "square.and.arrow.down")
                    }
                    .disabled(exporting)
                    if let exportError {
                        Text(exportError).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.danger)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text(model.isDemoMode
                         ? "Downloads the demo starter-project metadata as a JSON file."
                         : "Downloads all your projects and their metadata as a JSON file.")
                }
                .listRowBackground(Theme.raised.opacity(0.72))
                .listRowSeparatorTint(Theme.divider)

                Section("Help & Legal") {
                    Link(destination: WorkshopLinks.support) {
                        Label("Workshop Support", systemImage: "questionmark.circle")
                    }
                    Link(destination: WorkshopLinks.privacy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: WorkshopLinks.terms) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }
                .listRowBackground(Theme.raised.opacity(0.72))
                .listRowSeparatorTint(Theme.divider)

                Section {
                    if model.isDemoMode {
                        LabeledContent("Mode", value: "Demo · Read only")
                        Text("You can explore every starter project. Sign in when you are ready to create and sync your own workshop.")
                            .font(Theme.ui(13, .regular, relativeTo: .footnote))
                            .foregroundStyle(Theme.muted)
                        Button {
                            model.exitDemo()
                        } label: {
                            Label("Sign In to Create Projects", systemImage: "person.crop.circle.badge.plus")
                        }
                    } else {
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
                                        .tint(Theme.danger)
                                    Text("Deleting Account…")
                                        .foregroundStyle(Theme.danger)
                                }
                            } else {
                                Label("Delete Account", systemImage: "trash")
                                    .foregroundStyle(Theme.danger)
                            }
                        }

                        .disabled(deletingAccount)
                        if let accountDeletionError {
                            Text(accountDeletionError)
                                .font(Theme.ui(13, .regular, relativeTo: .footnote))
                                .foregroundStyle(Theme.danger)
                        }
                    }

                } header: {
                    Text("Account")
                } footer: {
                    Text(model.isDemoMode
                         ? "Demo data stays on this device only for the current session."
                         : "Delete Account permanently removes your Workshop projects, photos, lists, and account data. Export a project summary first if you want a reference copy.")
                }
                .listRowBackground(Theme.raised.opacity(0.72))
                .listRowSeparatorTint(Theme.divider)
                Section {
                    LabeledContent("Version", value: AppInfo.version)
                }
                .listRowBackground(Theme.raised.opacity(0.72))
                .listRowSeparatorTint(Theme.divider)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(PlanCanvasBackground())
            .environment(\.defaultMinListRowHeight, 50)
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

    /// Annotation colors shown directly as clean material swatches.
    private var annotationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Annotation Color")
                Spacer()
                Text(Palette.all.first { $0.id == theme.selection }?.name ?? "")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                ForEach(Palette.all) { p in
                    let on = p.id == theme.selection
                    Button { theme.selection = p.id } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(p.annotationFill.color)
                            if on {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    on ? Theme.ink : Theme.divider.opacity(0.7),
                                    lineWidth: on ? 2 : 1
                                )
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

    private func exportProjectSummary() async {
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
                .appendingPathComponent("workshop-project-summary-\(df.string(from: Date())).json")
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
            accountDeletionError = accountDeletionMessage(for: error)
        }
    }

    private func accountDeletionMessage(for error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "We couldn't confirm account deletion. Check your connection and try again."
        }
        switch apiError {
        case .unauthorized:
            return "Your session expired before deletion could be confirmed. Sign out, sign back in, and try again."
        case .http(409, let code) where code == "apple_reauthentication_required":
            return "Sign out, then sign in with Apple again before retrying. Apple requires one fresh sign-in before Workshop can revoke access."
        case .http(409, _):
            return "Another account operation is still finishing. Wait a moment, then try again."
        case .http(502, let code) where code == "apple_token_revocation_failed":
            return "Apple couldn't confirm that access was revoked, so Workshop kept your account intact. Try again."
        case .http(503, let code) where code == "apple_revocation_unavailable":
            return "Account deletion is temporarily unavailable. Your Workshop data remains intact; try again later."
        default:
            return "We couldn't confirm account deletion. Your local account is still signed in; try again."
        }
    }
}

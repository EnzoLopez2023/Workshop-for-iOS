import SwiftUI
import NintekKit

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
    @State private var thingiverseStatus: ThingiverseConnectionStatus?
    @State private var thingiverseToken = ""
    @State private var loadingProviderConnections = false
    @State private var savingThingiverseToken = false
    @State private var disconnectingThingiverse = false
    @State private var providerConnectionError: String?
    @State private var showingThingiverseDisconnectConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: appearanceBinding) {
                        ForEach(Appearance.allCases) { a in Text(a.label).tag(a) }
                    }
                    lampPicker
                    LabeledContent("Text Size", value: "Follows iOS Settings")
                }
                .listRowBackground(Theme.flap.opacity(0.72))
                .listRowSeparatorTint(Theme.line)

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
                            .tint(Theme.accentDeep)
                    } header: {
                        Text("Projects")
                    }
                    .listRowBackground(Theme.flap.opacity(0.72))
                    .listRowSeparatorTint(Theme.line)
                }

                if !model.isDemoMode {
                    providerConnectionsSection
                }

                Section {
                    NavigationLink {
                        InsightsView(api: api)
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                }
                .listRowBackground(Theme.flap.opacity(0.72))
                .listRowSeparatorTint(Theme.line)

                Section {
                    Button {
                        Task { await exportProjectSummary() }
                    } label: {
                        Label(exporting ? "Preparing…" : "Export Project Summary", systemImage: "square.and.arrow.down")
                    }
                    .disabled(exporting)
                    if let exportError {
                        Text(exportError).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.red)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text(model.isDemoMode
                         ? "Downloads the demo starter-project metadata as a JSON file."
                         : "Downloads woodworking project metadata as a JSON file. Bambu Hub files are not included; download or share those from each imported project.")
                }
                .listRowBackground(Theme.flap.opacity(0.72))
                .listRowSeparatorTint(Theme.line)

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
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text(model.isDemoMode
                         ? "Demo data stays on this device only for the current session."
                         : "Delete Account permanently removes your Workshop projects, photos, lists, Bambu Hub imports and their stored 3D files, and account data. Export woodworking project metadata and share any Bambu files you want to keep first.")
                }
                .listRowBackground(Theme.flap.opacity(0.72))
                .listRowSeparatorTint(Theme.line)
                Section {
                    LabeledContent("Version", value: AppInfo.version)
                }
                .listRowBackground(Theme.flap.opacity(0.72))
                .listRowSeparatorTint(Theme.line)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(PlanCanvasBackground())
            .environment(\.defaultMinListRowHeight, 50)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if !model.isDemoMode, thingiverseStatus == nil {
                    await loadProviderConnections()
                }
            }
            .onDisappear {
                thingiverseToken = ""
            }
            .sheet(item: $exportURL) { ActivityShareSheet(items: [$0.url]) }
            .confirmationDialog(
                "Disconnect your Thingiverse token?",
                isPresented: $showingThingiverseDisconnectConfirmation,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive) {
                    Task { await disconnectThingiverse() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Workshop will delete your encrypted account token. A shared server token, when available, remains active.")
            }
            .alert("Permanently Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("All projects, photos, cut lists, materials, Shaper projects, Bambu Hub imports and their stored images and 3D files, templates, and account data will be permanently deleted. This cannot be undone.")
            }
        }
    }

    private var providerConnectionsSection: some View {
        Section {
            if loadingProviderConnections, thingiverseStatus == nil {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking Thingiverse connection...")
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
            } else if let status = thingiverseStatus {
                LabeledContent("Thingiverse") {
                    Label(
                        status.connected ? "Connected" : "Not connected",
                        systemImage: status.connected ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(status.connected ? Theme.green : Theme.muted)
                }

                LabeledContent("Connection source", value: thingiverseSourceLabel(status.source))

                Text(thingiverseStatusExplanation(status))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if status.storageConfigured {
                    SecureField(
                        status.source == .account
                            ? "Replace official API token"
                            : "Official Thingiverse API token",
                        text: $thingiverseToken
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                    .accessibilityHint("The token is sent directly to encrypted server storage and is never shown again")

                    Button {
                        Task { await saveThingiverseToken() }
                    } label: {
                        if savingThingiverseToken {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Saving Token...")
                            }
                        } else {
                            Label(
                                status.source == .account ? "Replace Token" : "Save Token",
                                systemImage: "lock.shield"
                            )
                        }
                    }
                    .disabled(
                        savingThingiverseToken
                            || disconnectingThingiverse
                            || thingiverseToken
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                    )
                } else {
                    Label(
                        "Secure account-token storage is not configured on this Workshop server.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        "Configuration error: Secure account-token storage is not configured on this Workshop server."
                    )
                }

                if status.source == .account {
                    Button(role: .destructive) {
                        showingThingiverseDisconnectConfirmation = true
                    } label: {
                        if disconnectingThingiverse {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Disconnecting...")
                            }
                        } else {
                            Label("Disconnect Personal Token", systemImage: "link.badge.minus")
                        }
                    }
                    .disabled(savingThingiverseToken || disconnectingThingiverse)
                }
            } else {
                Button {
                    Task { await loadProviderConnections() }
                } label: {
                    Label("Retry Connection Check", systemImage: "arrow.clockwise")
                }
            }

            if let providerConnectionError {
                Text(providerConnectionError)
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Provider connection error: \(providerConnectionError)")
            }
        } header: {
            Text("Provider Connections")
        } footer: {
            Text("Use an official Thingiverse API token. Workshop sends it directly to encrypted server storage, never returns it, and never persists it on this device. Workshop never asks for MakerWorld credentials or cookies; add protected MakerWorld downloads from the imported project's Add Files action.")
        }
        .listRowBackground(Theme.flap.opacity(0.72))
        .listRowSeparatorTint(Theme.line)
    }

    /// Annotation colors shown directly as clean material swatches.
    private var lampPicker: some View {
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
                                .fill(p.accentFill.color)
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
                                    on ? Theme.ink : Theme.line.opacity(0.7),
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

    // MARK: Provider connections

    private func loadProviderConnections() async {
        guard !model.isDemoMode else { return }
        loadingProviderConnections = true
        providerConnectionError = nil
        defer { loadingProviderConnections = false }

        do {
            thingiverseStatus = try await api.providerConnections().thingiverse
        } catch {
            NSLog(
                "[Workshop] Provider connection status failed: %@",
                String(describing: error)
            )
            providerConnectionError = providerConnectionMessage(
                prefix: "Couldn't check the Thingiverse connection.",
                error: error
            )
        }
    }

    private func saveThingiverseToken() async {
        guard !model.isDemoMode else { return }
        let token = thingiverseToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        guard thingiverseStatus?.storageConfigured == true else {
            providerConnectionError = "Secure provider-token storage is not configured on the Workshop server."
            return
        }

        savingThingiverseToken = true
        providerConnectionError = nil
        defer { savingThingiverseToken = false }

        do {
            thingiverseStatus = try await api.saveThingiverseToken(token)
            thingiverseToken = ""
            Haptics.success()
            ToastCenter.shared.success("Thingiverse token connected")
        } catch {
            NSLog(
                "[Workshop] Thingiverse token validation or save failed: %@",
                String(describing: error)
            )
            Haptics.error()
            providerConnectionError = providerConnectionMessage(
                prefix: "Couldn't connect this official Thingiverse token.",
                error: error
            )
        }
    }

    private func disconnectThingiverse() async {
        guard !model.isDemoMode else { return }
        disconnectingThingiverse = true
        providerConnectionError = nil
        defer { disconnectingThingiverse = false }

        do {
            thingiverseStatus = try await api.deleteThingiverseToken()
            thingiverseToken = ""
            Haptics.success()
            ToastCenter.shared.success("Personal Thingiverse token disconnected")
        } catch {
            NSLog(
                "[Workshop] Thingiverse token disconnect failed: %@",
                String(describing: error)
            )
            Haptics.error()
            providerConnectionError = providerConnectionMessage(
                prefix: "Couldn't disconnect your Thingiverse token.",
                error: error
            )
        }
    }

    private func thingiverseSourceLabel(_ source: ThingiverseConnectionSource) -> String {
        switch source {
        case .account: "Your encrypted token"
        case .server: "Shared server token"
        case .none: "None"
        case .unknown: "Unrecognized"
        }
    }

    private func thingiverseStatusExplanation(_ status: ThingiverseConnectionStatus) -> String {
        switch status.source {
        case .account:
            "Your write-only token is encrypted for this Workshop account. The app cannot read it back."
        case .server:
            "A shared server token is active. You can save your own official token for this account when secure storage is configured."
        case .none:
            "Connect an official token to import complete Thingiverse metadata, images, and files."
        case .unknown:
            status.connected
                ? "Thingiverse is connected through a newer server connection type."
                : "Thingiverse is not currently connected."
        }
    }

    private func providerConnectionMessage(prefix: String, error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "\(prefix) \(error.localizedDescription)"
        }
        if case .http(_, let message) = apiError,
           let message,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(prefix) \(message)"
        }
        return "\(prefix) \(apiError.localizedDescription)"
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

import SwiftUI
import NintekKit

// Phase 1.2 placeholder screens. These prove the shell + dual-auth + API wiring
// end-to-end; Phase 2 replaces each with the real, field-complete port of its
// React page. The Dashboard performs a live `listProjects()` so the on-device
// sign-in verify step shows real data round-tripping from prod.

/// Simple async loading states for the placeholder fetches.
private enum LoadState<T> {
    case loading, loaded(T), failed(String)
}

struct DashboardView: View {
    let api: WorkshopAPI
    @State private var state: LoadState<[WSProject]> = .loading

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow("Workshop")
                    switch state {
                    case .loading:
                        ProgressView("Loading projects…").frame(maxWidth: .infinity).padding(.top, 40)
                    case .failed(let msg):
                        VStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.subtle)
                            Text("Couldn’t load projects").font(.headline).foregroundStyle(Theme.ink)
                            Text(msg).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
                            Button("Retry") { Task { await load() } }.padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 40)
                    case .loaded(let projects):
                        Text("\(projects.count) project\(projects.count == 1 ? "" : "s")")
                            .font(Theme.display(28)).foregroundStyle(Theme.ink)
                        ForEach(projects) { p in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.title).font(.headline).foregroundStyle(Theme.ink)
                                Text(p.status.label).font(.caption).foregroundStyle(Theme.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .wsCard()
                        }
                        if projects.isEmpty {
                            Text("No projects yet — add one on the web to see it here.")
                                .font(.subheadline).foregroundStyle(Theme.subtle).padding(.top, 8)
                        }
                    }
                }
                .contentColumn()
                .padding(20)
            }
            .creamBackground()
            .navigationTitle("Dashboard")
            .task { await load() }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await api.listProjects()) }
        catch { state = .failed(error.localizedDescription) }
    }
}

struct ProjectsView: View {
    let api: WorkshopAPI
    var body: some View { PlaceholderScreen(title: "Projects", symbol: "hammer.fill") }
}

struct ShaperView: View {
    let api: WorkshopAPI
    var body: some View { PlaceholderScreen(title: "Shaper", symbol: "cpu.fill") }
}

struct ShoppingView: View {
    let api: WorkshopAPI
    var body: some View { PlaceholderScreen(title: "Shopping", symbol: "cart.fill") }
}

struct MoreView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Accent", selection: Binding(
                        get: { theme.selection },
                        set: { theme.selection = $0 }
                    )) {
                        ForEach(Palette.all) { p in Text(p.name).tag(p.id) }
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
        }
    }
}

/// Generic "coming in Phase 2" placeholder body.
private struct PlaceholderScreen: View {
    let title: String
    let symbol: String
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(Theme.accent)
                Text(title).font(Theme.display(24)).foregroundStyle(Theme.ink)
                Text("Coming in Phase 2").font(.subheadline).foregroundStyle(Theme.subtle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .creamBackground()
            .navigationTitle(title)
        }
    }
}

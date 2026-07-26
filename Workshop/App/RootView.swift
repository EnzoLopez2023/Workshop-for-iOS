import SwiftUI

/// The app's top-level destinations, shared by the iPhone tab bar and the iPad
/// sidebar so the two layouts stay in sync from one source of truth.
enum AppDestination: String, CaseIterable, Identifiable {
    case dashboard, shopping, tables, more
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "Dashboard"; case .shopping: "Shopping"
        case .tables: "Tables"; case .more: "More"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2.fill"; case .shopping: "cart.fill"
        case .tables: "ruler.fill"; case .more: "ellipsis.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("ws.appearance") private var appearanceRaw = Appearance.system.rawValue
    // Web's "Large Text" bumps root font-size 6.25% (rem-based CSS scales
    // everything); the closest native lever is Dynamic Type scale, which only
    // moves text using relative fonts (nav titles, List/Form default text) —
    // Theme's explicit `.system(size:)` call sites are unaffected either way.
    @AppStorage("ws.fontSizeLarge") private var fontSizeLarge = false
    // Regular width = iPad full screen (and large split-view). Compact = iPhone,
    // and iPad slide-over / narrow split — where the tab bar is the right idiom.
    @Environment(\.horizontalSizeClass) private var hSize
    // Sidebar starts hidden on iPad (the system toolbar toggle shows it as an
    // overlay) — that's the ShopKeep-derived pattern and iPad keeps it as-is.
    // On Mac ("Designed for iPad", i.e. the iOS binary running unmodified on
    // Apple Silicon — not a separate Catalyst target) a permanently-collapsed
    // sidebar reads as broken rather than intentional, since Mac users expect
    // persistent sidebar navigation; default it open there instead.
    @State private var columnVisibility: NavigationSplitViewVisibility =
        ProcessInfo.processInfo.isiOSAppOnMac ? .all : .detailOnly

    @StateObject private var intentRouter = IntentRouter.shared

    var body: some View {
        Group {
            if model.isSignedIn {
                if hSize == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            } else {
                SignInView()
            }
        }
        .id(theme.selection)
        .preferredColorScheme((Appearance(rawValue: appearanceRaw) ?? .system).scheme)
        .dynamicTypeSize(fontSizeLarge ? .xLarge : .large)
        .onChange(of: intentRouter.requestedTab?.id) { _, _ in
            if let dest = intentRouter.requestedTab?.destination {
                model.selectedTab = dest.rawValue
            }
        }
    }

    // MARK: iPhone — bottom tab bar, full-width stacked content

    private var iPhoneLayout: some View {
        TabView(selection: $model.selectedTab) {
            ForEach(AppDestination.allCases) { dest in
                destination(dest)
                    .tabItem { Label(dest.title, systemImage: dest.icon) }
                    .tag(dest.rawValue)
            }
        }
        .tint(Theme.accent)
    }

    // MARK: iPad / large-iPhone-landscape — overlay sidebar split view

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: selection) {
                ForEach(AppDestination.allCases) { dest in
                    Label(dest.title, systemImage: dest.icon).tag(dest)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("")
            // ~20% narrower than the ~320pt default.
            .navigationSplitViewColumnWidth(min: 216, ideal: 260, max: 272)
            .safeAreaInset(edge: .top, spacing: 0) { sidebarHeader }
            .safeAreaInset(edge: .bottom, spacing: 0) { sidebarFooter }
        } detail: {
            destination(current)
                .id(current)   // reset the detail's nav stack when switching sections
        }
        .navigationSplitViewStyle(.prominentDetail)
        .tint(Theme.accent)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// Brand header pinned above the sidebar list — app icon + wordmark.
    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("Workshop").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
        .background(Theme.cream)
    }

    /// Footer pinned below the sidebar list — signed-in identity + version.
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider().overlay(Theme.line)
            if let name = model.userName {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    .padding(.top, 10)
            }
            Text(AppInfo.version).font(.caption2).foregroundStyle(Theme.subtle)
                .padding(.bottom, 12).padding(.top, model.userName == nil ? 10 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .background(Theme.cream)
    }

    // MARK: Shared

    /// One destination view, reused by both layouts. Each keeps its own
    /// NavigationStack, which becomes the tab's / detail column's navigation.
    @ViewBuilder private func destination(_ dest: AppDestination) -> some View {
        switch dest {
        case .dashboard: DashboardView(api: model.api)
        case .shopping:  ShoppingView(api: model.api)
        case .tables:    ConversionTablesView()
        case .more:      MoreView(api: model.api)
        }
    }

    private var current: AppDestination { AppDestination(rawValue: model.selectedTab) ?? .dashboard }
    private var selection: Binding<AppDestination?> {
        Binding(get: { current }, set: { if let v = $0 { model.selectedTab = v.rawValue } })
    }
}

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
    // Five-step text size (see `TextSize`). Dynamic Type is the native lever
    // the web's rem-based root font-size maps onto: it moves everything drawn
    // with a relative font, which is every face `Theme` hands out.
    @AppStorage(SettingsKeys.textSize) private var textSizeRaw = TextSize.standard.rawValue
    // Regular width = iPad full screen (and large split-view). Compact = iPhone,
    // and iPad slide-over / narrow split — where the tab bar is the right idiom.
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    // Sidebar starts hidden on iPad (the system toolbar toggle shows it as an
    // overlay) — that's the ShopKeep-derived pattern and iPad keeps it as-is.
    // On Mac ("Designed for iPad", i.e. the iOS binary running unmodified on
    // Apple Silicon — not a separate Catalyst target) a permanently-collapsed
    // sidebar reads as broken rather than intentional, since Mac users expect
    // persistent sidebar navigation; default it open there instead.
    @State private var columnVisibility: NavigationSplitViewVisibility = {
        // Dev/local: the sidebar is otherwise unreachable in an automated pass,
        // since the toggle can only be tapped by hand.
        #if DEBUG
        if ProcessInfo.processInfo.environment["WORKSHOP_SIDEBAR"] == "open" { return .all }
        #endif
        return ProcessInfo.processInfo.isiOSAppOnMac ? .all : .detailOnly
    }()

    @StateObject private var intentRouter = IntentRouter.shared

    var body: some View {
        Group {
            if model.isSignedIn {
                VStack(spacing: 0) {
                    if model.isDemoMode {
                        DemoModeRail()
                    }
                    if hSize == .regular {
                        iPadLayout
                    } else {
                        iPhoneLayout
                    }
                }
            } else {
                SignInView()
            }
        }
        .overlay(alignment: .top) { ToastOverlay() }
        .tint(Theme.accentDeep)
        .id(theme.selection)
        .preferredColorScheme((Appearance(rawValue: appearanceRaw) ?? .system).scheme)
        .dynamicTypeSize((TextSize(rawValue: textSizeRaw) ?? .standard).dynamicTypeSize)
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
        .tint(Theme.accentDeep)
    }

    // MARK: iPad / large-iPhone-landscape — overlay sidebar split view

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarRail
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
                // ~20% narrower than the ~320pt default.
                .navigationSplitViewColumnWidth(min: 216, ideal: 260, max: 272)
        } detail: {
            destination(current)
                .id(current)   // reset the detail's nav stack when switching sections
        }
        .navigationSplitViewStyle(.prominentDetail)
        .tint(Theme.accentDeep)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// The sidebar is the steel frame the board hangs on — the same face as the
    /// toolbar, so the two meet as one continuous edge instead of a light column
    /// butting into a dark bar. A system `.sidebar` list can't carry this: its
    /// background, type and selection capsule are all platform chrome.
    private var sidebarRail: some View {
        VStack(spacing: 0) {
            sidebarHeader
            VStack(spacing: 2) {
                ForEach(AppDestination.allCases) { dest in
                    Button { model.selectedTab = dest.rawValue } label: { railRow(dest) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            Spacer(minLength: 0)
            sidebarFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The rail slides in over the board rather than beside it, so it reads
        // as a panel pulled across the concourse: frosted steel, with the rows
        // behind it still faintly there. Opaque steel here would look like a
        // second screen had replaced the first.
        .background {
            if reduceTransparency {
                Theme.steel.ignoresSafeArea()
            } else {
                Theme.steel.opacity(0.8)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        }
    }

    /// A destination on the rail. The active one is lit: an amber lamp bar on
    /// the leading edge and a lifted steel plate behind it.
    private func railRow(_ dest: AppDestination) -> some View {
        let active = current == dest
        return HStack(spacing: 10) {
            Image(systemName: dest.icon)
                .font(.system(size: 13))
                .frame(width: 18)
            Text(dest.title.uppercased())
                .font(Theme.board(12, .semibold, relativeTo: .subheadline))
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .foregroundStyle(active ? Theme.onSteel : Theme.onSteel.opacity(0.62))
        .padding(.vertical, 11)
        .padding(.leading, 13)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? Theme.steelLight.opacity(0.75) : Color.clear)
        // The lamp bar rides in an overlay: a Rectangle with only a width set
        // has unbounded height and would stretch the row to the column.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(active ? Theme.accentFill : Color.clear)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        .contentShape(Rectangle())
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    /// Brand header pinned above the rail — the same steel lockup the sign-in
    /// plate uses, so the app announces itself the same way everywhere.
    private var sidebarHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accentFill)
            Text("THE WORKSHOP")
                .font(Theme.board(13, .bold, relativeTo: .headline))
                .tracking(1.6)
                .foregroundStyle(Theme.onSteel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 14)
        // Slightly sheer, so the band belongs to the frosted panel below it
        // instead of sitting on top of it as a separate solid plate.
        .background(Theme.steelFace.opacity(0.9))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.22)).frame(height: 1)
        }
    }

    /// Footer pinned below the rail — signed-in identity + version.
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Rectangle().fill(Color.black.opacity(0.22)).frame(height: 1)
                .padding(.horizontal, -16)
            if let name = model.userName {
                Text(name)
                    .font(Theme.ui(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Theme.onSteel.opacity(0.9))
                    .lineLimit(1)
                    .padding(.top, 12)
            }
            Text(AppInfo.version.uppercased())
                .font(Theme.board(9.5, .semibold, relativeTo: .caption2))
                .tracking(1.1)
                .foregroundStyle(Theme.onSteel.opacity(0.5))
                .padding(.bottom, 14)
                .padding(.top, model.userName == nil ? 12 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
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
}

private struct DemoModeRail: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.accentFill)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text("DEMO WORKSHOP")
                .font(Theme.board(10, .bold, relativeTo: .caption2))
                .tracking(1.2)
            Text("READ ONLY")
                .font(Theme.board(9, .semibold, relativeTo: .caption2))
                .tracking(1)
                .foregroundStyle(Theme.onSteel.opacity(0.7))
            Spacer(minLength: 8)
            Button("SIGN IN") {
                model.exitDemo()
            }
            .font(Theme.board(9.5, .bold, relativeTo: .caption2))
            .tracking(1)
            .foregroundStyle(Theme.onSteel)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.steelLight, in: RoundedRectangle(cornerRadius: Theme.rFlap))
            .buttonStyle(.plain)
            .accessibilityHint("Leaves the demo and returns to sign in")
        }
        .foregroundStyle(Theme.onSteel)
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .background(Theme.steelFace)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

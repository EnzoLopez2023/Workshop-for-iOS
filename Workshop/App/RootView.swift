import SwiftUI
import UIKit

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
    // Regular width = iPad full screen (and large split-view). Compact = iPad
    // slide-over / narrow split — where the tab bar is the right idiom.
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    // Living Plan Table treats the iPad sidebar as a persistent workbench rail,
    // not a modal drawer. Users may still collapse it with the system control.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @StateObject private var intentRouter = IntentRouter.shared

    /// Plus- and Max-class iPhones report regular width in landscape. Choosing
    /// the shell by width alone swaps the TabView for a new split-view tree on
    /// rotation, destroying the dashboard's navigation path. Phones keep their
    /// tab shell in both orientations; only a wide iPad uses the sidebar.
    private var usesSidebarLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && hSize == .regular
    }

    var body: some View {
        Group {
            if model.isSignedIn {
                VStack(spacing: 0) {
                    if model.isDemoMode {
                        DemoModeRail()
                    }
                    if usesSidebarLayout {
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
        .animation(.easeInOut(duration: 0.2), value: theme.selection)
        .preferredColorScheme((Appearance(rawValue: appearanceRaw) ?? .system).scheme)
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

    // MARK: iPad / wide windows — overlay sidebar split view

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
        .navigationSplitViewStyle(.balanced)
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
            VStack(spacing: 6) {
                ForEach(AppDestination.allCases) { dest in
                    SidebarDestinationButton(
                        destination: dest,
                        active: current == dest
                    ) {
                        model.selectedTab = dest.rawValue
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            Spacer(minLength: 0)
            sidebarFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            reduceTransparency ? AnyShapeStyle(Theme.flap) : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                .strokeBorder(Theme.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Theme.steelDark.opacity(0.12), radius: 18, x: 0, y: 8)
        .padding(12)
        .background(PlanCanvasBackground())
    }

    /// Brand header pinned above the persistent glass sidebar.
    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .frame(width: 34, height: 34)
                .background(Theme.tint(Theme.accent), in: RoundedRectangle(cornerRadius: 11))
            Text("Workshop")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line.opacity(0.7)).frame(height: 1)
        }
    }

    /// Footer pinned below the rail — signed-in identity + version.
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Rectangle().fill(Theme.line.opacity(0.7)).frame(height: 1)
                .padding(.horizontal, -16)
            if let name = model.userName {
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .padding(.top, 12)
            }
            Text(AppInfo.version)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
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

private struct SidebarDestinationButton: View {
    let destination: AppDestination
    let active: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: destination.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(destination.title)
                    .font(.system(.body, design: .rounded, weight: active ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(active ? Theme.accentDeep : Theme.ink.opacity(0.72))
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                active
                    ? Theme.tint(Theme.accent)
                    : Color.white.opacity(hovered ? 0.15 : 0),
                in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: hovered)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

private struct DemoModeRail: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "eye.fill")
                .font(.caption)
                .foregroundStyle(Theme.accentDeep)
            Text("Demo Workshop")
                .font(.system(.caption, design: .rounded, weight: .semibold))
            Text("Read only")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            Button("Sign In") {
                model.exitDemo()
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.accentDeep, in: RoundedRectangle(cornerRadius: 10))
            .buttonStyle(.plain)
            .accessibilityHint("Leaves the demo and returns to sign in")
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line.opacity(0.7)).frame(height: 1)
        }
    }
}

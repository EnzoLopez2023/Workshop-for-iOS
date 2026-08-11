import SwiftUI
import WidgetKit
import NintekKit

/// Navigation targets pushed from the Dashboard grids.
enum DashboardRoute: Hashable {
    case project(Int)
    case shaper(Int)
}

/// The home screen — full parity with the web `Dashboard.tsx`: the shop board,
/// search + status filter, project grid, Shaper Hub section, templates, and DIY
/// links. Templates' clone/delete and the "Add project" actions are writes,
/// deferred to Phase 3. Details push via NavigationLink.
struct DashboardView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var projects: [WSProject] = []
    @State private var shaper: [ShaperProject] = []
    @State private var templates: [WSTemplate] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var filter: StatusFilter = .all
    @State private var search = ""
    @State private var path: [DashboardRoute] = []
    @State private var showNewProject = false
    @State private var newProjectSourceURL: String?
    @State private var showNewShaper = false
    @State private var cloningTemplateId: Int?
    @State private var confirmDeleteTemplateId: Int?
    @State private var pendingShares: [PendingShareItem] = []
    @State private var showPendingShares = false
    @StateObject private var intentRouter = IntentRouter.shared

    @AppStorage(SettingsKeys.dashboardSort) private var dashboardSortRaw = DashboardSort.updated.rawValue
    @AppStorage(SettingsKeys.showCompletedByDefault) private var showCompletedByDefault = false

    private let grid = [GridItem(.adaptive(minimum: 240), spacing: 18)]

    /// The shop board is exactly four cells wide when there is room for them.
    /// An adaptive grid would lay out eight columns on an iPad and leave the
    /// last four as a dead slab of line colour.
    private var shopBoardColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: hSize == .regular ? 4 : 2)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !model.isDemoMode, !pendingShares.isEmpty {
                        sharedItemsBanner.padding(.bottom, 20)
                    }
                    if loading {
                        LazyVGrid(columns: grid, spacing: 18) {
                            ForEach(0..<6, id: \.self) { _ in ProjectCardSkeletonView() }
                        }
                    } else if let err = loadError {
                        errorState(err)
                    } else {
                        if !projects.isEmpty { shopBoard.padding(.bottom, 24) }
                        searchAndFilters.padding(.bottom, 20)
                        projectGrid
                        shaperSection.padding(.top, 44)
                        if !templates.isEmpty { templatesSection.padding(.top, 44) }
                        diySection.padding(.top, 44)
                    }
                }
                .contentColumn(900)
                .padding(20)
            }
            .boardBackground()
            .navigationTitle("Dashboard")
            // The shop board *is* this screen's header — a large system title
            // above it would be a second, emptier one.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !model.isDemoMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        BoardToolbarButton(symbol: "plus", label: "New Project", tone: .amber) {
                            showNewProject = true
                        }
                    }
                    .boardToolbarItem()
                }
            }
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .project(let id): ProjectDetailView(api: api, projectId: id)
                case .shaper(let id):  ShaperDetailView(api: api, shaperId: id)
                }
            }
            .sheet(isPresented: $showNewProject) {
                ProjectFormView(api: api, projectId: nil, initialSourceUrl: newProjectSourceURL) { newId in
                    newProjectSourceURL = nil
                    Task { await load() }
                    path.append(.project(newId))
                }
            }
            .sheet(isPresented: $showNewShaper) {
                ShaperProjectFormView(api: api, shaperId: nil) { newId in
                    Task { await load() }
                    path.append(.shaper(newId))
                }
            }
            .sheet(isPresented: $showPendingShares) {
                PendingSharesView(api: api, items: pendingShares) { url in
                    newProjectSourceURL = url
                    showNewProject = true
                } onHandled: { item in
                    ShareQueue.remove(item)
                    pendingShares.removeAll { $0.id == item.id }
                }
            }
            .task { await load() }
            .task {
                if !model.isDemoMode {
                    pendingShares = ShareQueue.loadAll()
                }
            }
            .refreshable { await load() }
            .onAppear { consumePendingProject(); consumeQuickAction() }
            .onChange(of: model.pendingProjectId) { _, _ in consumePendingProject() }
            .onChange(of: intentRouter.requestedAction?.id) { _, _ in consumeQuickAction() }
        }
    }

    // MARK: Sections

    /// Home Screen Quick Action → "New Project" (see `AppDelegate`/`IntentRouter`).
    /// Same onAppear-and-onChange belt-and-suspenders as `consumePendingProject`,
    /// since a cold-launch quick action sets this before this view first exists.
    private func consumeQuickAction() {
        guard let action = intentRouter.requestedAction?.action else { return }
        intentRouter.requestedAction = nil
        guard !model.isDemoMode else { return }
        switch action {
        case .newProject: showNewProject = true
        }
    }

    /// `onChange` alone drops a deep link that arrives during a cold launch,
    /// because the id is already set before this view is first evaluated.
    private func consumePendingProject() {
        #if DEBUG
        if let sid = model.pendingShaperId {
            model.pendingShaperId = nil
            path.append(.shaper(sid))
        }
        #endif
        guard let id = model.pendingProjectId else { return }
        model.pendingProjectId = nil
        path.append(.project(id))
    }

    /// Surfaces items the Share Extension queued (Phase 7.5) — "Add to
    /// Workshop" from Safari/Photos/Pinterest — until the user reviews them.
    private var sharedItemsBanner: some View {
        Button { showPendingShares = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square.fill").foregroundStyle(Theme.accent)
                Text("\(pendingShares.count) item\(pendingShares.count == 1 ? "" : "s") shared with Workshop")
                    .font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink)
                Spacer()
                Text("Review").font(Theme.ui(13, .medium)).foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.flapShade, in: RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    /// The shop board — the app's signature surface. Four values that roll to
    /// themselves on load, the way a departure board sets itself when it wakes.
    private var shopBoard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("SHOP BOARD")
                    .font(Theme.board(11, .bold, relativeTo: .caption))
                    .tracking(1.5)
                    .foregroundStyle(Theme.onSteel)
                Spacer(minLength: 8)
                Text(boardClock)
                    .font(Theme.board(10, .semibold, relativeTo: .caption2))
                    .tracking(1.0)
                    .foregroundStyle(Theme.accentFill)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.steelFace)

            LazyVGrid(columns: shopBoardColumns, spacing: 1) {
                DashCell(label: "In Progress", value: pad(inProgressCount, 2),
                         sub: "active builds", tone: .amber)
                DashCell(label: "In Queue", value: pad(queuedCount, 2),
                         sub: "ideas & plans")
                DashCell(label: "Total Parts", value: pad(totalParts, 3),
                         sub: "across active projects")
                DashCell(label: "Est. Value", value: "$" + estValue.formatted(.number.grouping(.automatic)),
                         sub: "in materials")
            }
            .background(Theme.line)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rPanel)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    /// Board figures are zero-padded to a fixed width, so a cell never shows a
    /// blank flap where a digit belongs and the row never changes width.
    private func pad(_ value: Int, _ width: Int) -> String {
        String(format: "%0\(width)d", value)
    }

    private var inProgressCount: Int { projects.filter { $0.status == .inProgress }.count }
    private var queuedCount: Int { projects.filter { $0.status == .idea || $0.status == .planning }.count }
    private var totalParts: Int {
        projects.filter { $0.status != .completed }.reduce(0) { $0 + ($1.partsCount ?? 0) }
    }
    private var estValue: Int {
        let rounded = projects.reduce(0.0) { $0 + ($1.totalCost ?? 0) }.rounded()
        guard rounded.isFinite, rounded > 0 else { return 0 }
        guard rounded < Double(Int.max) else { return Int.max }
        return Int(rounded)
    }

    /// Board clock — the departure-board dateline, not a live ticking clock.
    private var boardClock: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date()).uppercased()
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                TextField("Search projects, wood types…", text: $search)
                    .font(Theme.ui(14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Theme.flap)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(StatusFilter.allCases) { f in
                        let active = filter == f
                        Button { filter = f } label: {
                            Text(f.label.uppercased())
                                .font(Theme.board(10, .semibold, relativeTo: .caption2))
                                .tracking(1.0)
                                .foregroundStyle(active ? Theme.onSteel : Theme.muted)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(active ? Theme.steel : Theme.flap)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
    }

    @ViewBuilder private var projectGrid: some View {
        let items = filteredProjects
        if items.isEmpty {
            Text(projects.isEmpty ? "No projects yet. Start by capturing your first idea on the web."
                                  : "No projects match those filters.")
                .font(Theme.ui(15, .regular, relativeTo: .subheadline)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            LazyVGrid(columns: grid, spacing: 18) {
                ForEach(items) { p in
                    NavigationLink(value: DashboardRoute.project(p.id)) {
                        ProjectCard(project: p, heroURL: heroURL(p.heroImageId))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shaperSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rail("Shaper Tools Hub — CNC", count: shaper.count) {
                if !model.isDemoMode {
                    Button { showNewShaper = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(Theme.board(10, .semibold, relativeTo: .caption2))
                            .foregroundStyle(Theme.onSteel)
                    }
                }
            }
            if shaper.isEmpty {
                Text("No Shaper Hub projects yet.")
                    .font(Theme.ui(15, .regular, relativeTo: .subheadline)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Theme.flap, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
            } else {
                LazyVGrid(columns: grid, spacing: 18) {
                    ForEach(shaper) { s in
                        NavigationLink(value: DashboardRoute.shaper(s.id)) {
                            ShaperProjectCard(project: s, heroURL: shaperHeroURL(s))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rail("Project Templates", count: templates.count)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                ForEach(templates) { t in
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            if let url = heroURL(t.heroImageId) {
                                AuthImage(url: url, contentMode: .fill)
                            } else {
                                ZStack { Theme.flapShade; Image(systemName: "doc.on.doc").font(Theme.ui(28, .bold, relativeTo: .title)).foregroundStyle(Theme.muted.opacity(0.5)) }
                            }
                        }
                        .frame(height: 100).frame(maxWidth: .infinity).clipped()
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.templateName ?? t.title).font(Theme.ui(16, .bold)).foregroundStyle(Theme.ink).lineLimit(2)
                                Text("\(t.difficulty.rawValue) · \(t.partsCount) part\(t.partsCount == 1 ? "" : "s")")
                                    .font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                            }
                            if !model.isDemoMode {
                                HStack(spacing: 8) {
                                    Button {
                                        Task { await useTemplate(t) }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "doc.on.doc")
                                            Text(cloningTemplateId == t.id ? "Creating…" : "Use Template")
                                        }
                                        .font(Theme.ui(12, .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                    }
                                    .disabled(cloningTemplateId == t.id)
                                    .background(Theme.steel, in: RoundedRectangle(cornerRadius: 3))
                                    .foregroundStyle(Theme.concourse)
                                    .buttonStyle(.plain)

                                    if confirmDeleteTemplateId == t.id {
                                        Button("Cancel") { confirmDeleteTemplateId = nil }
                                            .font(Theme.ui(12, .regular))
                                            .minimumHitTarget()
                                        Button { Task { await deleteTemplate(t) } } label: {
                                            Image(systemName: "trash").foregroundStyle(Theme.red)
                                        }
                                        .minimumHitTarget()
                                        .accessibilityLabel("Confirm delete \(t.templateName ?? t.title) template")
                                    } else {
                                        Button { confirmDeleteTemplateId = t.id } label: {
                                            Image(systemName: "trash").foregroundStyle(Theme.muted)
                                        }
                                        .minimumHitTarget()
                                        .accessibilityLabel("Delete \(t.templateName ?? t.title) template")
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                    .background(Theme.flap).clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
                }
            }
        }
    }

    private var diySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rail("Build Inspiration")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(DIYSite.all) { site in
                    Link(destination: site.url) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.name).font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                                Text(site.tagline).font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.flap, in: RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark").font(Theme.ui(34, .bold, relativeTo: .largeTitle)).foregroundStyle(Theme.muted)
            Text("Couldn’t load your workshop").font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(Theme.ink)
            Text(msg).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
    }

    // MARK: Data

    private var filteredProjects: [WSProject] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let base = projects.filter { p in
            if filter != .all, p.status != filter.status { return false }
            if filter == .all, !showCompletedByDefault, p.status == .completed { return false }
            if q.isEmpty { return true }
            let hay = "\(p.title) \(p.description ?? "") \(p.woodTypes.joined(separator: " ")) \(p.cutListNames ?? "") \(p.materialNames ?? "")".lowercased()
            return hay.contains(q)
        }
        switch DashboardSort(rawValue: dashboardSortRaw) ?? .updated {
        case .updated: return base.sorted { $0.updatedAt > $1.updatedAt }
        case .created: return base.sorted { $0.createdAt > $1.createdAt }
        case .title:   return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private func heroURL(_ id: Int?) -> URL? {
        guard let id, let key = model.userKey else { return nil }
        return api.imageURL(imageId: id, userKey: key)
    }

    private func shaperHeroURL(_ s: ShaperProject) -> URL? {
        if let id = s.heroImageId { return heroURL(id) }
        if let photo = s.photoUrl, let url = URL(string: photo) { return url }
        return nil
    }

    private func load() async {
        loading = projects.isEmpty && shaper.isEmpty
        loadError = nil
        // Reconcile any "check off" taps the shopping-list widget or the
        // shopping Live Activity recorded while backgrounded (see
        // ToggleShoppingItemIntent / ToggleShoppingActivityItemIntent) —
        // neither can authenticate itself, so the real writes happen here.
        if !model.isDemoMode {
            for pendingId in WorkshopWidgetStore.consumePendingShoppingToggles() {
                do { try await api.setPurchased(id: pendingId, purchased: true) }
                catch { NSLog("[Workshop] Widget shopping-toggle reconciliation failed for id=%d: %@", pendingId, String(describing: error)) }
            }
        }
        do {
            async let p = api.listProjects()
            async let s = api.listShaperProjects()
            async let t = api.listTemplates()
            (projects, shaper, templates) = try await (p, s, t)
            if !model.isDemoMode {
                await seedStarterContentIfNeeded()
                var snapshot = WorkshopWidgetSnapshot(projects: projects)
                snapshot.shoppingItems = WorkshopWidgetStore.load()?.shoppingItems ?? []
                WorkshopWidgetStore.save(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
                SpotlightIndexer.index(projects: projects)
            }
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    /// A new account otherwise opens on "No projects yet", which asks the user
    /// to invent something before the app has shown them what a record here
    /// even looks like. Fill it once, with builds they can edit or delete —
    /// ``StarterSeeder`` owns the once-only, empty-account-only guard.
    private func seedStarterContentIfNeeded() async {
        guard !model.isDemoMode else { return }
        let userKey = model.userKey
        guard !StarterSeeder.hasRun(userKey: userKey) else { return }
        // Marked before the writes, not after: a seed that half-fails must not
        // come back on the next pull-to-refresh and duplicate what did land.
        StarterSeeder.markRun(userKey: userKey)
        guard projects.isEmpty, shaper.isEmpty, templates.isEmpty else { return }

        let created = await StarterSeeder.seed(api: api)
        guard created > 0 else { return }
        do {
            async let p = api.listProjects()
            async let s = api.listShaperProjects()
            (projects, shaper) = try await (p, s)
        } catch {
            NSLog("[Workshop] Reload after seeding starter content failed: %@", String(describing: error))
        }
        ToastCenter.shared.success("Added \(created) starter projects to get you going.")
    }

    private func useTemplate(_ t: WSTemplate) async {
        guard !model.isDemoMode else { return }
        cloningTemplateId = t.id
        do {
            let project = try await api.cloneTemplate(templateId: t.id)
            Haptics.success()
            cloningTemplateId = nil
            path.append(.project(project.id))
        } catch {
            cloningTemplateId = nil
        }
    }

    private func deleteTemplate(_ t: WSTemplate) async {
        guard !model.isDemoMode else { return }
        confirmDeleteTemplateId = nil
        templates.removeAll { $0.id == t.id }
        do { try await api.deleteTemplate(id: t.id) }
        catch { await load() }
    }
}

// MARK: - Supporting types

/// One cell of the shop board — a label plate, a split-flap value, and the
/// unit beneath it.
private struct DashCell: View {
    let label: String
    let value: String
    let sub: String
    var tone: SplitFlap.Tone = .letter

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            BoardCaps(label)
            SplitFlap(value, label: "\(label): \(value)", size: 21, tone: tone)
            Text(sub)
                .font(Theme.ui(10))
                .foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .background(Theme.flap)
    }
}

enum StatusFilter: String, CaseIterable, Identifiable {
    case all, idea, planning, inProgress, completed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "All"; case .idea: "Ideas"; case .planning: "Planning"
        case .inProgress: "In Progress"; case .completed: "Completed"
        }
    }
    var status: ProjectStatus? {
        switch self {
        case .all: nil; case .idea: .idea; case .planning: .planning
        case .inProgress: .inProgress; case .completed: .completed
        }
    }
}

/// How the dashboard grid orders projects — parity with the web's
/// `defaultDashboardSort` setting (`Settings.tsx`).
enum DashboardSort: String, CaseIterable, Identifiable {
    case updated, created, title
    var id: String { rawValue }
    var label: String {
        switch self {
        case .updated: "Last Updated"
        case .created: "Date Created"
        case .title: "Title (A–Z)"
        }
    }
}

struct DIYSite: Identifiable {
    let id = UUID()
    let name: String, tagline: String, url: URL
    static let all: [DIYSite] = [
        DIYSite(name: "Kreg Tool Plans", tagline: "Pocket-hole projects & free plans", url: URL(string: "https://learn.kregtool.com/projects-plans/")!),
        DIYSite(name: "Shanty 2 Chic", tagline: "Farmhouse builds on a budget", url: URL(string: "https://www.shanty-2-chic.com/")!),
        DIYSite(name: "Ana White", tagline: "Free plans for every skill level", url: URL(string: "https://www.ana-white.com/")!),
        DIYSite(name: "Houseful of Handmade", tagline: "Modern DIY furniture & home decor", url: URL(string: "https://housefulofhandmade.com/")!),
    ]
}

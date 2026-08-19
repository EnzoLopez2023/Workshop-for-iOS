/*
 THESIS: A project is one living plan whose active layer is always the next
 action; this replaces summary-card dashboards and the Concourse Board metaphor.
 OWN-WORLD: Cool vellum canvas, deep spruce ink, pencil-blue annotations, native
 frosted glass, SF typography, and 14-point squircle controls.
 STORY: The woodworker sees the active build, understands its current phase,
 continues the next task, then scans the rest of the workshop.
 FIRST VIEWPORT: The active project plan/photo owns the canvas; a glass action
 layer sits above it, with project stages and the remaining library below.
 FORM: Grounded direction 3 of 7, direction-native layered plan-table staging,
 seed ef48c050, approved from the Living Plan Table sketch.
 */
import SwiftUI
import WidgetKit
import NintekKit

/// Navigation targets pushed from the Dashboard grids.
enum DashboardRoute: Hashable {
    case project(Int)
    case shaper(Int)
}

/// The home screen: active build and next action first, followed by the
/// searchable project library, Shaper work, templates, and inspiration.
struct DashboardView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var projects: [WSProject] = []
    @State private var shaper: [ShaperProject] = []
    @State private var templates: [WSTemplate] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var filter: StatusFilter = .all
    @State private var showProjectFilters = false
    @State private var pendingFilter: StatusFilter?
    @SceneStorage("ws.dashboard.page") private var dashboardPageRaw = DashboardPage.projects.rawValue
    @State private var projectSearch = ""
    @State private var shaperSearch = ""
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

    private let grid = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !model.isDemoMode, !pendingShares.isEmpty {
                        sharedItemsBanner.padding(.bottom, 20)
                    }
                    if loading {
                        loadingPage
                    } else if let err = loadError {
                        errorState(err)
                    } else {
                        dashboardContent
                    }
                }
                .contentColumn(900)
                .padding(20)
            }
            .boardBackground()
            .safeAreaInset(edge: .top, spacing: 0) {
                dashboardPageSwitcher
            }
            .navigationTitle("Workshop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if hSize == .compact {
                    ToolbarItem(placement: .topBarLeading) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accentDeep)
                            .accessibilityHidden(true)
                    }
                }
                if dashboardPage == .projects {
                    ToolbarItem(placement: .topBarTrailing) {
                        BoardToolbarButton(
                            symbol: filter == .all
                                ? "line.3.horizontal.decrease"
                                : "line.3.horizontal.decrease.circle.fill",
                            label: "Filter Projects, \(filter.label) selected"
                        ) {
                            pendingFilter = nil
                            showProjectFilters = true
                        }
                    }
                    .boardToolbarItem()
                }

                if !model.isDemoMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                selectDashboardPage(.projects)
                                showNewProject = true
                            } label: {
                                Label("New Project", systemImage: "square.and.pencil")
                            }
                            Button {
                                selectDashboardPage(.shaperHub)
                                showNewShaper = true
                            } label: {
                                Label("New Shaper Hub Project", systemImage: "cpu")
                            }
                        } label: {
                            createMenuLabel
                        }
                        .accessibilityLabel("Add a project")
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
                    selectDashboardPage(.projects)
                    newProjectSourceURL = nil
                    Task { await load() }
                    path.append(.project(newId))
                }
            }
            .sheet(isPresented: $showNewShaper) {
                ShaperProjectFormView(api: api, shaperId: nil) { newId in
                    selectDashboardPage(.shaperHub)
                    Task { await load() }
                    path.append(.shaper(newId))
                }
            }
            .sheet(isPresented: $showProjectFilters, onDismiss: commitPendingFilter) {
                DashboardFilterSheet(applied: filter) { selected in
                    pendingFilter = selected
                    showProjectFilters = false
                }
            }
            .sheet(isPresented: $showPendingShares) {
                PendingSharesView(api: api, items: pendingShares) { url in
                    selectDashboardPage(.projects)
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

    private var dashboardPage: DashboardPage {
        DashboardPage(rawValue: dashboardPageRaw) ?? .projects
    }

    private var dashboardPageBinding: Binding<DashboardPage> {
        Binding(
            get: { dashboardPage },
            set: { selectDashboardPage($0) }
        )
    }

    private func selectDashboardPage(_ page: DashboardPage) {
        guard dashboardPageRaw != page.rawValue else { return }
        if reduceMotion {
            dashboardPageRaw = page.rawValue
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                dashboardPageRaw = page.rawValue
            }
        }
    }

    private var dashboardPageSwitcher: some View {
        HStack {
            Picker("Project type", selection: dashboardPageBinding) {
                ForEach(DashboardPage.allCases) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .accessibilityValue(dashboardPage.label)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.line.opacity(0.6))
                .frame(height: 0.5)
        }
        .sensoryFeedback(.selection, trigger: dashboardPageRaw)
    }

    private var createMenuLabel: some View {
        Image(systemName: "plus")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                Theme.accentDeep,
                in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
            )
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    @ViewBuilder private var loadingPage: some View {
        if dashboardPage == .projects {
            VStack(spacing: 16) {
                ProjectCardSkeletonView()
                LazyVGrid(columns: grid, spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in ProjectCardSkeletonView() }
                }
            }
        } else {
            LazyVGrid(columns: grid, spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in ProjectCardSkeletonView() }
            }
        }
    }

    @ViewBuilder private var dashboardContent: some View {
        switch dashboardPage {
        case .projects:
            projectsPage
                .transition(.opacity)
        case .shaperHub:
            shaperHubPage
                .transition(.opacity)
        }
    }

    private var projectsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let project = focusProject {
                activeProjectLayer(project)
                    .padding(.bottom, 30)
            }
            projectSearchAndFilters.padding(.bottom, 26)
            projectLibrary
            if !templates.isEmpty { templatesSection.padding(.top, 42) }
            diySection.padding(.top, 42)
        }
    }

    private var shaperHubPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            shaperSearchField.padding(.bottom, 26)
            shaperLibrary
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
        case .newProject:
            selectDashboardPage(.projects)
            showNewProject = true
        }
    }

    /// `onChange` alone drops a deep link that arrives during a cold launch,
    /// because the id is already set before this view is first evaluated.
    private func consumePendingProject() {
        #if DEBUG
        if let sid = model.pendingShaperId {
            model.pendingShaperId = nil
            selectDashboardPage(.shaperHub)
            path.append(.shaper(sid))
        }
        #endif
        guard let id = model.pendingProjectId else { return }
        model.pendingProjectId = nil
        selectDashboardPage(.projects)
        path.append(.project(id))
    }

    private func commitPendingFilter() {
        guard let selected = pendingFilter else { return }
        pendingFilter = nil
        guard selected != filter else { return }
        filter = selected
    }

    /// Surfaces items the Share Extension queued (Phase 7.5) — "Add to
    /// Workshop" from Safari/Photos/Pinterest — until the user reviews them.
    private var sharedItemsBanner: some View {
        Button { showPendingShares = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .foregroundStyle(Theme.accentDeep)
                Text("\(pendingShares.count) item\(pendingShares.count == 1 ? "" : "s") shared with Workshop")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Review")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentDeep)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .planGlass(elevated: false)
            .contentShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func activeProjectLayer(_ project: WSProject) -> some View {
        NavigationLink(value: DashboardRoute.project(project.id)) {
            Group {
                if hSize == .regular {
                    ZStack(alignment: .trailing) {
                        projectPlanVisual(project)
                            .frame(maxWidth: .infinity)
                        nextActionLayer(project)
                            .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
                            .padding(28)
                    }
                    .frame(minHeight: 380)
                } else {
                    VStack(spacing: -34) {
                        projectPlanVisual(project)
                            .frame(height: 310)
                        nextActionLayer(project)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .background(Theme.flap.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: Theme.rHero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rHero, style: .continuous)
                    .strokeBorder(Theme.line.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: Theme.steelDark.opacity(0.14), radius: 22, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: Theme.rHero, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: project.id)
        .accessibilityLabel(
            "\(focusLabel(for: project)). \(project.title). \(nextAction(for: project).title)."
        )
        .accessibilityHint("Opens this project")
    }

    private func projectPlanVisual(_ project: WSProject) -> some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Theme.flapShade)
                .overlay {
                    if heroURL(project.heroImageId) != nil {
                        AuthImage(url: heroURL(project.heroImageId), contentMode: .fill)
                            .allowsHitTesting(false)
                    } else {
                        PlanCanvasBackground()
                            .overlay {
                                Image(systemName: "pencil.and.ruler.fill")
                                    .font(.system(size: hSize == .regular ? 58 : 44, weight: .medium))
                                    .foregroundStyle(Theme.accent.opacity(0.34))
                            }
                    }
                }
                .clipped()

            LinearGradient(
                colors: [.clear, Theme.steelDark.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(focusLabel(for: project))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(project.title)
                    .font(
                        .system(
                            hSize == .regular ? .largeTitle : .title,
                            design: .rounded,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                StatusBadge(status: project.status, withBackdrop: true)
            }
            .padding(hSize == .regular ? 28 : 22)
        }
        .accessibilityHidden(true)
    }

    private func nextActionLayer(_ project: WSProject) -> some View {
        let action = nextAction(for: project)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: action.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.accentDeep, in: RoundedRectangle(cornerRadius: 11))
                Text("Next action")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(action.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(action.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Label("\(project.partsCount ?? 0) parts", systemImage: "square.stack.3d.up")
                Label(
                    project.estimatedHours > 0 ? "\(project.estimatedHours)h" : "Hours open",
                    systemImage: "clock"
                )
            }
            .font(.caption)
            .foregroundStyle(Theme.muted)

            ProjectStageTrack(status: project.status)

            HStack {
                Text("Open Project")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(
                Theme.accentDeep,
                in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
            )
        }
        .padding(20)
        .planGlass()
    }

    private func focusLabel(for project: WSProject) -> String {
        switch project.status {
        case .inProgress: "Active build"
        case .planning: "Ready to plan"
        case .idea: "Next idea"
        case .completed: "Recent project"
        case .unknown: "Project"
        }
    }

    private func nextAction(for project: WSProject) -> ProjectNextAction {
        switch project.status {
        case .idea:
            ProjectNextAction(
                title: "Shape the idea",
                detail: "Add dimensions, reference photos, and the first parts when you are ready.",
                symbol: "pencil.and.ruler"
            )
        case .planning where (project.partsCount ?? 0) == 0:
            ProjectNextAction(
                title: "Build the cut list",
                detail: "Turn the plan into measured parts before choosing materials.",
                symbol: "list.bullet.rectangle"
            )
        case .planning where project.woodTypes.isEmpty:
            ProjectNextAction(
                title: "Choose the stock",
                detail: "Match the planned parts to the wood you want to build with.",
                symbol: "tree"
            )
        case .planning:
            ProjectNextAction(
                title: "Review and start",
                detail: "Confirm the parts and materials, then move the project into the shop.",
                symbol: "checklist"
            )
        case .inProgress:
            ProjectNextAction(
                title: "Continue the build",
                detail: "Open the project, review the plan, and record the work you complete next.",
                symbol: "hammer.fill"
            )
        case .completed:
            ProjectNextAction(
                title: "Review the finished build",
                detail: "Keep the photos, finish details, and lessons ready for the next project.",
                symbol: "checkmark.seal.fill"
            )
        case .unknown:
            ProjectNextAction(
                title: "Open the project",
                detail: "Review the project record and choose the next useful step.",
                symbol: "arrow.right.circle"
            )
        }
    }

    private var projectSearchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                TextField("Search projects, wood types…", text: $projectSearch)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .planGlass(elevated: false)

            if filter != .all {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Showing \(filter.label)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Button("Clear") { filter = .all }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .minimumHitTarget()
                }
                .padding(.leading, 14)
                .planGlass(elevated: false)
            }
        }
    }

    private var projectLibrary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rail(projectSearch.isEmpty && filter == .all ? "Project Library" : "Results",
                 count: libraryProjects.count)
            projectGrid
        }
    }

    @ViewBuilder private var projectGrid: some View {
        let items = libraryProjects
        if items.isEmpty {
            Text(projects.isEmpty ? "No projects yet. Capture your first build idea."
                                  : "No other projects match these filters.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            LazyVGrid(columns: grid, spacing: 16) {
                ForEach(items) { p in
                    NavigationLink(value: DashboardRoute.project(p.id)) {
                        ProjectCard(project: p, heroURL: heroURL(p.heroImageId))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: Theme.rPanel))
                    .hoverEffect(.highlight)
                }
            }
        }
    }

    private var shaperSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            TextField("Search Shaper projects, materials…", text: $shaperSearch)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .planGlass(elevated: false)
    }

    private var shaperLibrary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rail(shaperSearch.trimmingCharacters(in: .whitespaces).isEmpty
                 ? "Shaper Hub Projects"
                 : "Results",
                 count: filteredShaperProjects.count)
            shaperGrid
        }
    }

    @ViewBuilder private var shaperGrid: some View {
        if shaper.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.accentDeep)
                Text("No Shaper Hub projects yet")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Create a project from a Shaper Tools Hub share URL, then keep its materials, photos, and cut plan together here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.isDemoMode {
                    Button {
                        showNewShaper = true
                    } label: {
                        Label("New Shaper Hub Project", systemImage: "plus")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .background(
                                Theme.accentDeep,
                                in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .planGlass(elevated: false)
        } else if filteredShaperProjects.isEmpty {
            VStack(spacing: 10) {
                Text("No Shaper Hub projects match that search.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Button("Clear Search") {
                    shaperSearch = ""
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accentDeep)
                .minimumHitTarget()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            LazyVGrid(columns: grid, spacing: 16) {
                ForEach(filteredShaperProjects) { project in
                    NavigationLink(value: DashboardRoute.shaper(project.id)) {
                        ShaperProjectCard(project: project, heroURL: shaperHeroURL(project))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: Theme.rPanel))
                    .hoverEffect(.highlight)
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
                                    .allowsHitTesting(false)
                            } else {
                                PlanCanvasBackground()
                                    .overlay {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(Theme.accent.opacity(0.42))
                                    }
                            }
                        }
                        .frame(height: 132)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.templateName ?? t.title)
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(2)
                                Text("\(t.difficulty.rawValue) · \(t.partsCount) part\(t.partsCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
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
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 44)
                                    }
                                    .disabled(cloningTemplateId == t.id)
                                    .background(
                                        Theme.accentDeep,
                                        in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                                    )
                                    .foregroundStyle(.white)
                                    .buttonStyle(.plain)

                                    if confirmDeleteTemplateId == t.id {
                                        Button("Cancel") { confirmDeleteTemplateId = nil }
                                            .font(.subheadline)
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
                        .padding(16)
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                            .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
                    )
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
                                Text(site.name)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(site.tagline)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accentDeep)
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 62)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .planGlass(elevated: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func errorState(_ msg: String) -> some View {
        let title = dashboardPage == .projects
            ? "Couldn’t load projects"
            : "Couldn’t load Shaper Hub"
        return VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark").font(Theme.ui(34, .bold, relativeTo: .largeTitle)).foregroundStyle(Theme.muted)
            Text(title).font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(Theme.ink)
            Text(msg).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
    }

    // MARK: Data

    private var focusProject: WSProject? {
        for status in [
            ProjectStatus.inProgress,
            .planning,
            .idea,
            .completed,
            .unknown,
        ] {
            if let project = projects
                .filter({ $0.status == status })
                .max(by: { $0.updatedAt < $1.updatedAt }) {
                return project
            }
        }
        return nil
    }

    private var libraryProjects: [WSProject] {
        let items = filteredProjects
        let hasExplicitQuery = !projectSearch.trimmingCharacters(in: .whitespaces).isEmpty || filter != .all
        guard !hasExplicitQuery, let focusProject else { return items }
        return items.filter { $0.id != focusProject.id }
    }

    private var filteredShaperProjects: [ShaperProject] {
        let query = shaperSearch.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = shaper.filter { project in
            guard !query.isEmpty else { return true }
            let materials = project.materials
                .map { "\($0.name) \($0.qty)" }
                .joined(separator: " ")
            let cutList = project.cutList
                .map { "\($0.partName) \($0.material ?? "")" }
                .joined(separator: " ")
            let haystack = [
                project.title,
                project.description ?? "",
                project.shaperUrl,
                project.instructions ?? "",
                materials,
                cutList,
            ]
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(query)
        }
        return matching.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredProjects: [WSProject] {
        let q = projectSearch.trimmingCharacters(in: .whitespaces).lowercased()
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

private enum DashboardPage: String, CaseIterable, Identifiable {
    case projects
    case shaperHub

    var id: String { rawValue }

    var label: String {
        switch self {
        case .projects: "Projects"
        case .shaperHub: "Shaper Hub"
        }
    }
}

/// Status selection stays outside the scrolling project content. The chosen
/// value is committed by DashboardView only after this sheet has dismissed, so
/// rebuilding the grid cannot interrupt the control handling the selection.
private struct DashboardFilterSheet: View {
    let onApply: (StatusFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: StatusFilter

    init(applied: StatusFilter, onApply: @escaping (StatusFilter) -> Void) {
        self.onApply = onApply
        _draft = State(initialValue: applied)
    }

    var body: some View {
        NavigationStack {
            List(StatusFilter.allCases) { option in
                Button { draft = option } label: {
                    HStack(spacing: 12) {
                        Text(option.label)
                            .font(Theme.ui(16))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if draft == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accentDeep)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(draft == option ? [.isButton, .isSelected] : .isButton)
            }
            .navigationTitle("Filter Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onApply(draft) }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accentDeep)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ProjectNextAction {
    let title: String
    let detail: String
    let symbol: String
}

private struct ProjectStageTrack: View {
    let status: ProjectStatus

    private let stages: [(status: ProjectStatus, label: String)] = [
        (.idea, "Idea"),
        (.planning, "Plan"),
        (.inProgress, "Build"),
        (.completed, "Done"),
    ]

    private var currentIndex: Int {
        stages.firstIndex { $0.status == status } ?? 0
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(stages.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index <= currentIndex ? Theme.accentDeep : Theme.flapShade)
                            .frame(width: 18, height: 18)
                        if index < currentIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        } else if index == currentIndex {
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(stages[index].label)
                        .font(.caption2)
                        .foregroundStyle(index == currentIndex ? Theme.ink : Theme.muted)
                }
                if index < stages.count - 1 {
                    Capsule()
                        .fill(index < currentIndex ? Theme.accentDeep : Theme.line)
                        .frame(maxWidth: .infinity)
                        .frame(height: 2)
                        .offset(y: -10)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Project stage: \(status.label)")
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

import SwiftUI
import WidgetKit
import NintekKit

/// Navigation targets pushed from the Dashboard grids.
enum DashboardRoute: Hashable {
    case project(Int)
    case shaper(Int)
}

/// The home screen — full parity with the web `Dashboard.tsx`: hero, stats strip,
/// search + status filter, project grid, Shaper Hub section, templates, and DIY
/// links. Templates' clone/delete and the "Add project" actions are writes,
/// deferred to Phase 3. Details push via NavigationLink.
struct DashboardView: View {
    let api: WorkshopAPI
    @EnvironmentObject private var model: AppModel

    @State private var projects: [WSProject] = []
    @State private var shaper: [ShaperProject] = []
    @State private var templates: [WSTemplate] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var filter: StatusFilter = .all
    @State private var search = ""
    @State private var path: [DashboardRoute] = []
    @State private var showNewProject = false
    @State private var showNewShaper = false
    @State private var cloningTemplateId: Int?
    @State private var confirmDeleteTemplateId: Int?

    @AppStorage(SettingsKeys.dashboardSort) private var dashboardSortRaw = DashboardSort.updated.rawValue
    @AppStorage(SettingsKeys.showCompletedByDefault) private var showCompletedByDefault = false

    private let grid = [GridItem(.adaptive(minimum: 240), spacing: 18)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else if let err = loadError {
                        errorState(err)
                    } else {
                        if !projects.isEmpty { statsStrip.padding(.bottom, 28) }
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
            .creamBackground()
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewProject = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .project(let id): ProjectDetailView(api: api, projectId: id)
                case .shaper(let id):  ShaperDetailView(api: api, shaperId: id)
                }
            }
            .sheet(isPresented: $showNewProject) {
                ProjectFormView(api: api, projectId: nil) { newId in
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
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: model.pendingProjectId) { _, id in
                if let id { path.append(.project(id)); model.pendingProjectId = nil }
            }
        }
    }

    // MARK: Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("◆").font(.system(size: 10))
                Text("Your Workshop Journal").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.creamSoft, in: Capsule())

            (Text("Every project,\n").foregroundStyle(Theme.ink)
             + Text("from sketch to sawdust.").foregroundStyle(Theme.accent).italic())
                .font(.system(size: 34, weight: .bold))
                .lineSpacing(2)

            Text("Capture ideas, gather inspiration, plan your cuts, and keep every detail of your woodworking projects in one considered place.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 32)
    }

    private var statsStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            DashStat(label: "In Progress", value: "\(projects.filter { $0.status == .inProgress }.count)", sub: "active builds")
            DashStat(label: "In Queue", value: "\(projects.filter { $0.status == .idea || $0.status == .planning }.count)", sub: "ideas & plans")
            DashStat(label: "Total Parts", value: "\(projects.filter { $0.status != .completed }.reduce(0) { $0 + ($1.partsCount ?? 0) })", sub: "across active")
            DashStat(label: "Est. Value", value: "$\(Int(projects.reduce(0.0) { $0 + ($1.totalCost ?? 0) }.rounded()))", sub: "in materials")
        }
        .padding(.vertical, 18).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1))
    }

    private var searchAndFilters: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.subtle)
                TextField("Search projects, wood types…", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Theme.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StatusFilter.allCases) { f in
                        let active = filter == f
                        Button { filter = f } label: {
                            Text(f.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(active ? Theme.cream : Theme.ink)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(active ? Theme.inkSoft : Theme.creamSoft, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var projectGrid: some View {
        let items = filteredProjects
        if items.isEmpty {
            Text(projects.isEmpty ? "No projects yet. Start by capturing your first idea on the web."
                                  : "No projects match those filters.")
                .font(.subheadline).foregroundStyle(Theme.subtle)
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
            HStack(spacing: 10) {
                Image(systemName: "cpu").font(.system(size: 13)).foregroundStyle(Theme.accent)
                Eyebrow("Shaper Tools Hub — CNC Projects")
                Spacer()
                Button { showNewShaper = true } label: {
                    Label("Add Project", systemImage: "plus").font(.system(size: 12, weight: .medium))
                }
            }
            if shaper.isEmpty {
                Text("No Shaper Hub projects yet.")
                    .font(.subheadline).foregroundStyle(Theme.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
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
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc").font(.system(size: 13)).foregroundStyle(Theme.accent)
                Eyebrow("Project Templates")
                Text("\(templates.count)")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subtle)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.creamSoft, in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                ForEach(templates) { t in
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            if let url = heroURL(t.heroImageId) {
                                AuthImage(url: url, contentMode: .fill)
                            } else {
                                ZStack { Theme.creamSoft; Image(systemName: "doc.on.doc").font(.title).foregroundStyle(Theme.subtle.opacity(0.5)) }
                            }
                        }
                        .frame(height: 100).frame(maxWidth: .infinity).clipped()
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.templateName ?? t.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text("\(t.difficulty.rawValue) · \(t.partsCount) part\(t.partsCount == 1 ? "" : "s")")
                                    .font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            }
                            HStack(spacing: 8) {
                                Button {
                                    Task { await useTemplate(t) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "doc.on.doc")
                                        Text(cloningTemplateId == t.id ? "Creating…" : "Use Template")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                }
                                .disabled(cloningTemplateId == t.id)
                                .background(Theme.inkSoft, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(Theme.cream)
                                .buttonStyle(.plain)

                                if confirmDeleteTemplateId == t.id {
                                    Button("Cancel") { confirmDeleteTemplateId = nil }
                                        .font(.system(size: 12))
                                    Button { Task { await deleteTemplate(t) } } label: {
                                        Image(systemName: "trash").foregroundStyle(Theme.fail)
                                    }
                                } else {
                                    Button { confirmDeleteTemplateId = t.id } label: {
                                        Image(systemName: "trash").foregroundStyle(Theme.subtle)
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                    .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
                }
            }
        }
    }

    private var diySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "hammer").font(.system(size: 13)).foregroundStyle(Theme.accent)
                Eyebrow("Build Inspiration — Where the Sawdust Starts")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(DIYSite.all) { site in
                    Link(destination: site.url) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(site.tagline).font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 13)).foregroundStyle(Theme.subtle)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.subtle)
            Text("Couldn’t load your workshop").font(.headline).foregroundStyle(Theme.ink)
            Text(msg).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
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
        do {
            async let p = api.listProjects()
            async let s = api.listShaperProjects()
            async let t = api.listTemplates()
            (projects, shaper, templates) = try await (p, s, t)
            WorkshopWidgetStore.save(WorkshopWidgetSnapshot(projects: projects))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    private func useTemplate(_ t: WSTemplate) async {
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
        confirmDeleteTemplateId = nil
        templates.removeAll { $0.id == t.id }
        do { try await api.deleteTemplate(id: t.id) }
        catch { await load() }
    }
}

// MARK: - Supporting types

private struct DashStat: View {
    let label: String, value: String, sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.subtle)
                .lineLimit(2, reservesSpace: true)
            Text(value).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.system(size: 10)).foregroundStyle(Theme.subtle).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

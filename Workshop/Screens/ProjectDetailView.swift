import SwiftUI
import PhotosUI
import NintekKit

/// Project detail — parity with `ProjectDetail.tsx`: hero banner + overlapping
/// meta card (status, title, description, plan links, stat grid), wood/tools
/// chips, sketches + inspiration galleries (with PDF tiles → PDFKit), cut-list
/// table, materials (with optimistic purchased toggle), finish log CRUD,
/// build-log CRUD (note + optional photo), linked projects CRUD, save-as-
/// template, and delete with confirm.
struct ProjectDetailView: View {
    let api: WorkshopAPI
    let projectId: Int
    @EnvironmentObject private var model: AppModel

    @State private var d: WSProjectDetail?
    @State private var loading = true
    @State private var loadError: String?
    @State private var gallery: GalleryPreview?
    @State private var pdfURL: IdentifiableURL?
    @State private var exportURL: IdentifiableURL?
    @State private var showEditForm = false
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var savedAsTemplate = false

    // Finish log
    @State private var showFinishForm = false
    @State private var finishForm = FinishFormState()
    @State private var finishSaving = false

    // Build log
    @State private var showBuildForm = false
    @State private var buildNote = ""
    @State private var buildPhotoData: Data?
    @State private var buildPhotoItem: PhotosPickerItem?
    @State private var buildSaving = false
    @State private var buildUploadProgress: Double?

    // Linked projects
    @State private var showLinkForm = false
    @State private var allProjects: [WSProject] = []
    @State private var linkProjectId: Int?
    @State private var linkRelationship = "related"
    @State private var linkSaving = false

    // Cut plan optimizer
    @State private var showCutPlan = false

    var body: some View {
        ScrollView {
            if let d {
                VStack(spacing: 0) {
                    hero(d)
                    VStack(alignment: .leading, spacing: 0) {
                        metaCard(d).padding(.top, heroImage(d) != nil ? -70 : 16)
                        if !d.woodTypes.isEmpty || !d.toolsNeeded.isEmpty { chips(d).padding(.top, 28) }
                        sketchesSection(d)
                        inspirationSection(d)
                        cutListSection(d)
                        if !d.cutList.isEmpty { cutPlanSection(d) }
                        materialsSection(d)
                        finishLogSection(d)
                        buildLogSection(d)
                        linksSection(d)
                        footer
                    }
                    .padding(.horizontal, 20)
                    .contentColumn()
                }
                .padding(.bottom, 40)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
            } else if let err = loadError {
                errorState(err)
            }
        }
        .creamBackground()
        .navigationTitle(d?.title ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if d != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditForm = true } label: { Image(systemName: "pencil") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await saveAsTemplate() }
                        } label: {
                            Label(savedAsTemplate ? "Saved!" : "Save as Template",
                                 systemImage: savedAsTemplate ? "checkmark" : "doc.on.doc")
                        }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Delete this project?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteProject() } }
            Button("Cancel", role: .cancel) {}
        }
        .task { await load() }
        .fullScreenCover(item: $gallery) { ImageLightbox(preview: $0) }
        .sheet(item: $pdfURL) { PDFViewerSheet(url: $0.url) }
        .sheet(item: $exportURL) { ActivityShareSheet(items: [$0.url]) }
        .sheet(isPresented: $showEditForm) {
            ProjectFormView(api: api, projectId: projectId) { _ in
                Task { await load() }
            }
        }
    }

    // MARK: Hero + meta

    @ViewBuilder private func hero(_ d: WSProjectDetail) -> some View {
        if let img = heroImage(d), let url = imageURL(img.id) {
            AuthImage(url: url, contentMode: .fill)
                .frame(height: 300).frame(maxWidth: .infinity).clipped()
                .overlay(
                    LinearGradient(colors: [.clear, Theme.cream.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)
                )
        } else {
            Theme.creamSoft.frame(height: 60)
        }
    }

    private func metaCard(_ d: WSProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge(status: d.status)
            Text(d.title).font(Theme.display(28)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let desc = d.description, !desc.isEmpty {
                Text(desc).font(.system(size: 15)).foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if d.sourceUrl != nil || d.cutPlanUrl != nil {
                FlowLayout(spacing: 16) {
                    if let s = d.sourceUrl, let u = URL(string: s) {
                        Link(destination: u) { linkLabel("View original plans", "arrow.up.forward.square") }
                    }
                    if let c = d.cutPlanUrl, let u = URL(string: c) {
                        Link(destination: u) { linkLabel("OptiCutter cut plan", "scissors") }
                    }
                }
            }

            Divider().overlay(Theme.line).padding(.top, 8)
            HStack(alignment: .top, spacing: 12) {
                Stat(icon: "gauge.medium", label: "Difficulty", value: d.difficulty.rawValue.capitalized)
                Stat(icon: "clock", label: "Est. Hours", value: "\(d.estimatedHours)h")
                Stat(icon: "square.stack.3d.up", label: "Parts", value: "\(d.partsCount)")
                Stat(icon: "dollarsign.circle", label: "Est. Cost", value: money(d.totalCost))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: Color(red: 0.23, green: 0.14, blue: 0.06).opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private func linkLabel(_ text: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12))
            Text(text).font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(Theme.accent)
    }

    private func chips(_ d: WSProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ChipGroup(label: "WOOD", items: d.woodTypes)
            ChipGroup(label: "TOOLS", items: d.toolsNeeded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Galleries

    @ViewBuilder private func sketchesSection(_ d: WSProjectDetail) -> some View {
        let sketches = d.images.filter { $0.kind == .sketch }
        if !sketches.isEmpty {
            let previewURLs = sketches.filter { !$0.isPDF }.compactMap { imageURL($0.id) }
            SectionBox(title: "Sketches & Plans") {
                imageGrid {
                    ForEach(sketches) { img in
                        if img.isPDF {
                            Button { if let u = imageURL(img.id) { pdfURL = IdentifiableURL(url: u) } } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: "doc.text.fill").font(.system(size: 32)).foregroundStyle(Theme.accent)
                                    Text("Open PDF").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink)
                                }
                                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                .background(Theme.creamSoft, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
                            }.buttonStyle(.plain)
                        } else if let url = imageURL(img.id) {
                            Button { gallery = GalleryPreview(urls: previewURLs, index: previewURLs.firstIndex(of: url) ?? 0) } label: {
                                squareImageTile(url: url)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func inspirationSection(_ d: WSProjectDetail) -> some View {
        let inspiration = d.images.filter { $0.kind == .inspiration }
        if !inspiration.isEmpty {
            let urls = inspiration.compactMap { inspirationURL($0) }
            SectionBox(title: "Inspiration") {
                imageGrid {
                    ForEach(inspiration) { img in
                        if let url = inspirationURL(img) {
                            Button { gallery = GalleryPreview(urls: urls, index: urls.firstIndex(of: url) ?? 0) } label: {
                                squareImageTile(url: url)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// A properly-bounded square grid tile. `AuthImage`'s `.fill` content mode
    /// only clips correctly once its own frame is a *definite* square — inside
    /// a `LazyVGrid`, `.aspectRatio(1, contentMode: .fill)` on the image itself
    /// has an ambiguous proposed height and can overflow into the row below
    /// (this caused the sketch/inspiration tiles to visually overlap). Sizing a
    /// `Color.clear` square first, via `.fit`, gives the grid a definite cell
    /// size; the image then fills *that* fixed square instead of guessing.
    private func squareImageTile(url: URL?) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { AuthImage(url: url, contentMode: .fill).clipped() }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func imageGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) { content() }
    }

    // MARK: Cut list

    @ViewBuilder private func cutListSection(_ d: WSProjectDetail) -> some View {
        if !d.cutList.isEmpty {
            SectionBox(title: "Cut List",
                       trailing: AnyView(HStack(spacing: 10) {
                        Text("\(d.cutList.count) part\(d.cutList.count == 1 ? "" : "s")")
                            .font(.system(size: 13)).foregroundStyle(Theme.subtle)
                        Button {
                            if let url = CSVExport.cutListCSV(d.cutList, projectTitle: d.title) {
                                exportURL = IdentifiableURL(url: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                        }
                       })) {
                VStack(spacing: 0) {
                    ForEach(Array(d.cutList.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider().overlay(Theme.line) }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(c.partName).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                Text("×\(c.qty)").font(.system(size: 14, weight: .medium).monospacedDigit()).foregroundStyle(Theme.subtle)
                            }
                            HStack(spacing: 6) {
                                Text(formatDims(c)).font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.subtle)
                                if let m = c.material, !m.isEmpty {
                                    Text("· \(m)").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    // MARK: Cut plan optimizer

    private func cutPlanSection(_ d: WSProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: showCutPlan ? 16 : 0) {
            HStack {
                Text("Cut Plan Optimizer").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button { showCutPlan.toggle() } label: {
                    Label(showCutPlan ? "Hide" : "Plan Cuts", systemImage: "scissors").font(.system(size: 13))
                }
            }
            if showCutPlan {
                CutPlanOptimizerView(api: api, cutList: d.cutList, projectId: d.id)
            }
        }
        .padding(.top, 36)
    }

    // MARK: Materials

    @ViewBuilder private func materialsSection(_ d: WSProjectDetail) -> some View {
        if !d.materials.isEmpty {
            SectionBox(title: "Materials & Hardware",
                       trailing: AnyView(HStack(spacing: 10) {
                        Text("Total: \(money(d.totalCost))").font(.system(size: 13)).foregroundStyle(Theme.subtle)
                        Button {
                            if let url = CSVExport.materialsCSV(d.materials, projectTitle: d.title) {
                                exportURL = IdentifiableURL(url: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                        }
                       })) {
                VStack(spacing: 0) {
                    ForEach(Array(d.materials.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Divider().overlay(Theme.line) }
                        Button { Task { await togglePurchased(m) } } label: {
                            HStack(spacing: 14) {
                                Image(systemName: m.purchased ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(m.purchased ? Theme.accent : Theme.subtle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name).font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(m.purchased ? Theme.subtle : Theme.ink)
                                        .strikethrough(m.purchased)
                                    if let q = m.qtyLabel, !q.isEmpty {
                                        Text(q).font(.system(size: 12)).foregroundStyle(Theme.subtle)
                                    }
                                }
                                Spacer()
                                Text(money(m.cost)).font(.system(size: 14).monospacedDigit())
                                    .foregroundStyle(m.purchased ? Theme.subtle : Theme.ink).strikethrough(m.purchased)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: m.purchased)
                    }
                }
                .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    // MARK: Finish log

    private static let finishTypes = ["Stain", "Oil", "Wax", "Varnish", "Lacquer", "Sealant", "Primer", "Paint", "Other"]

    @ViewBuilder private func finishLogSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Finish Log", icon: "drop.fill",
                   trailing: AnyView(toggleButton(showFinishForm, "Add Entry") {
                       if showFinishForm { finishForm = FinishFormState() }
                       showFinishForm.toggle()
                   })) {
            if showFinishForm {
                finishAddForm()
            }
            if d.finishLog.isEmpty && !showFinishForm {
                emptyNote("No finish entries yet.")
            } else if !d.finishLog.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(d.finishLog.enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Divider().overlay(Theme.line) }
                        HStack(spacing: 12) {
                            if let ft = e.finishType {
                                Circle().fill(finishColor(ft)).frame(width: 10, height: 10)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e.productName).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(finishMeta(e)).font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            }
                            Spacer()
                            Text(shortDate(e.appliedAt)).font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            Button { Task { await deleteFinishEntry(e) } } label: {
                                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                }
                .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    private func finishAddForm() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Product name (e.g. Minwax Early American)", text: $finishForm.productName)
            Picker("Type", selection: $finishForm.finishType) {
                Text("— select —").tag("")
                ForEach(Self.finishTypes, id: \.self) { Text($0).tag($0.lowercased()) }
            }
            TextField("Color", text: $finishForm.color)
            HStack {
                TextField("Coats", text: $finishForm.coats).keyboardType(.numberPad)
                DatePicker("Applied", selection: $finishForm.appliedAt, displayedComponents: .date)
                    .labelsHidden()
            }
            TextField("Notes", text: $finishForm.notes)
            Button {
                Task { await addFinishEntry() }
            } label: {
                Text(finishSaving ? "Saving…" : "Save Entry")
            }
            .disabled(finishSaving || finishForm.productName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    // MARK: Build log

    @ViewBuilder private func buildLogSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Build Log", icon: "book.closed.fill",
                   trailing: AnyView(toggleButton(showBuildForm, "Add Note") {
                       if showBuildForm { buildNote = ""; buildPhotoData = nil; buildPhotoItem = nil }
                       showBuildForm.toggle()
                   })) {
            if showBuildForm {
                buildAddForm()
            }
            if d.buildLog.isEmpty && !showBuildForm {
                emptyNote("No build notes yet. Document your progress here.")
            } else if !d.buildLog.isEmpty {
                VStack(spacing: 12) {
                    ForEach(d.buildLog) { e in
                        HStack(alignment: .top, spacing: 14) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.inkSoft).frame(width: 3)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(shortDate(e.createdAt)).font(.system(size: 12)).foregroundStyle(Theme.subtle)
                                if !e.note.isEmpty {
                                    Text(e.note).font(.system(size: 14)).foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if e.hasPhoto, let url = buildLogURL(e.id) {
                                    Button { gallery = GalleryPreview(urls: [url], index: 0) } label: {
                                        AuthImage(url: url, contentMode: .fill)
                                            .frame(maxWidth: 260).frame(height: 180).clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }.buttonStyle(.plain)
                                }
                            }
                            Spacer(minLength: 0)
                            Button { Task { await deleteBuildEntry(e) } } label: {
                                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func buildAddForm() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Cut all the legs to length… First coat looks great…", text: $buildNote, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                PhotosPicker(selection: $buildPhotoItem, matching: .images) {
                    Label(buildPhotoData == nil ? "Attach photo" : "Photo attached", systemImage: "camera")
                }
                .onChange(of: buildPhotoItem) { _, item in
                    Task {
                        if let item, let data = try? await item.loadTransferable(type: Data.self) { buildPhotoData = data }
                    }
                }
                if buildPhotoData != nil {
                    Button("Remove") { buildPhotoData = nil; buildPhotoItem = nil }
                        .font(.system(size: 13)).foregroundStyle(Theme.subtle)
                }
            }
            .font(.system(size: 14))
            if let pct = buildUploadProgress {
                ProgressView(value: pct).tint(Theme.accent)
            }
            Button {
                Task { await addBuildEntry() }
            } label: {
                Text(buildSaving ? "Saving…" : "Save Note")
            }
            .disabled(buildSaving || (buildNote.trimmingCharacters(in: .whitespaces).isEmpty && buildPhotoData == nil))
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    // MARK: Linked projects

    @ViewBuilder private func linksSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Linked Projects", icon: "link",
                   trailing: AnyView(toggleButton(showLinkForm, "Link Project") {
                       showLinkForm.toggle()
                       if showLinkForm { Task { await loadAllProjects() } }
                   })) {
            if showLinkForm {
                linkAddForm(d)
            }
            if d.links.isEmpty && !showLinkForm {
                emptyNote("No linked projects.")
            } else if !d.links.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(d.links.enumerated()), id: \.element.id) { i, link in
                        if i > 0 { Divider().overlay(Theme.line) }
                        HStack(spacing: 12) {
                            Image(systemName: "link").font(.system(size: 12)).foregroundStyle(Theme.subtle)
                            Text(link.linkedTitle).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(link.relationship).font(.system(size: 11)).foregroundStyle(Theme.subtle)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.creamSoft, in: Capsule())
                            StatusBadge(status: link.linkedStatus)
                            Button { Task { await removeLink(link) } } label: {
                                Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.subtle)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    private func linkAddForm(_ d: WSProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Project", selection: $linkProjectId) {
                Text("— select a project —").tag(Int?.none)
                ForEach(allProjects.filter { $0.id != d.id }) { p in
                    Text(p.title).tag(Int?.some(p.id))
                }
            }
            Picker("Relationship", selection: $linkRelationship) {
                ForEach(["related", "parent", "child", "sequel", "variant"], id: \.self) { r in
                    Text(r.capitalized).tag(r)
                }
            }
            Button {
                Task { await addLink() }
            } label: {
                Text(linkSaving ? "Linking…" : "Link")
            }
            .disabled(linkSaving || linkProjectId == nil)
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func toggleButton(_ shown: Bool, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(shown ? "Cancel" : label, systemImage: shown ? "chevron.up" : "plus")
                .font(.system(size: 13))
        }
    }

    private var footer: some View {
        Text("Measure twice · Cut once")
            .font(.system(size: 13)).italic().foregroundStyle(Theme.subtle)
            .frame(maxWidth: .infinity).padding(.top, 40)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn’t load project").font(.headline).foregroundStyle(Theme.ink)
            Text(msg).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
        }.frame(maxWidth: .infinity).padding(.top, 80)
    }

    private func emptyNote(_ t: String) -> some View {
        Text(t).font(.system(size: 14)).foregroundStyle(Theme.subtle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Data + helpers

    private func heroImage(_ d: WSProjectDetail) -> WSImage? {
        d.images.first { $0.kind == .sketch && !$0.isPDF }
    }
    private func imageURL(_ id: Int) -> URL? {
        guard let key = model.userKey else { return nil }
        return api.imageURL(imageId: id, userKey: key)
    }
    private func inspirationURL(_ img: WSImage) -> URL? {
        if let u = img.imageUrl, let url = URL(string: u) { return url }
        return imageURL(img.id)
    }
    private func buildLogURL(_ entryId: Int) -> URL? {
        guard let key = model.userKey else { return nil }
        return api.buildLogImageURL(entryId: entryId, userKey: key)
    }

    private func load() async {
        loading = d == nil; loadError = nil
        do { d = try await api.project(id: projectId) }
        catch { loadError = error.localizedDescription }
        loading = false
    }

    // MARK: Materials — optimistic purchased toggle

    private func togglePurchased(_ m: WSMaterial) async {
        guard let idx = d?.materials.firstIndex(where: { $0.id == m.id }) else { return }
        let next = !m.purchased
        d?.materials[idx].purchased = next
        do { try await api.setPurchased(id: m.id, purchased: next) }
        catch { await load() }
    }

    // MARK: Save as template / delete

    private func saveAsTemplate() async {
        guard let d else { return }
        do {
            _ = try await api.saveAsTemplate(projectId: d.id, name: d.title)
            Haptics.success()
            savedAsTemplate = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            savedAsTemplate = false
        } catch { /* best-effort, matches the web */ }
    }

    private func deleteProject() async {
        deleting = true
        do {
            try await api.deleteProject(id: projectId)
            Haptics.success()
            dismiss()
        } catch {
            deleting = false
        }
    }

    // MARK: Finish log

    private func addFinishEntry() async {
        finishSaving = true
        let f = finishForm
        let dateStr = Self.ymdOutput.string(from: f.appliedAt)
        let input = FinishLogInput(
            productName: f.productName,
            finishType: f.finishType.isEmpty ? nil : f.finishType,
            color: f.color.isEmpty ? nil : f.color,
            coats: Int(f.coats),
            notes: f.notes.isEmpty ? nil : f.notes,
            appliedAt: dateStr
        )
        do {
            _ = try await api.addFinishLogEntry(projectId: projectId, input)
            Haptics.success()
            await load()
            finishForm = FinishFormState()
            showFinishForm = false
        } catch { /* keep form open with entered data on failure */ }
        finishSaving = false
    }

    private func deleteFinishEntry(_ e: FinishLogEntry) async {
        d?.finishLog.removeAll { $0.id == e.id }
        do { try await api.deleteFinishLogEntry(id: e.id) }
        catch { await load() }
    }

    // MARK: Build log

    private func addBuildEntry() async {
        guard let projectId = d?.id else { return }
        buildSaving = true
        do {
            let file = buildPhotoData.flatMap { data -> MultipartFile? in
                guard let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) else { return nil }
                return MultipartFile(filename: "build-\(Int(Date().timeIntervalSince1970)).jpg",
                                     mimeType: "image/jpeg", data: jpeg)
            }
            let entry = try await api.addBuildLogEntry(projectId: projectId, note: buildNote, file: file) { pct in
                Task { @MainActor in buildUploadProgress = pct }
            }
            d?.buildLog.insert(entry, at: 0)
            Haptics.success()
            buildNote = ""; buildPhotoData = nil; buildPhotoItem = nil; buildUploadProgress = nil
            showBuildForm = false
        } catch { /* keep form open on failure */ }
        buildSaving = false
    }

    private func deleteBuildEntry(_ e: BuildLogEntry) async {
        d?.buildLog.removeAll { $0.id == e.id }
        do { try await api.deleteBuildLogEntry(id: e.id) }
        catch { await load() }
    }

    // MARK: Linked projects

    private func loadAllProjects() async {
        guard allProjects.isEmpty else { return }
        allProjects = (try? await api.listProjects()) ?? []
    }

    private func addLink() async {
        guard let linkProjectId, let projectId = d?.id else { return }
        linkSaving = true
        do {
            try await api.addProjectLink(projectId: projectId, linkedProjectId: linkProjectId, relationship: linkRelationship)
            Haptics.success()
            await load()
            self.linkProjectId = nil; showLinkForm = false
        } catch { /* keep form open on failure */ }
        linkSaving = false
    }

    private func removeLink(_ link: ProjectLink) async {
        d?.links.removeAll { $0.id == link.id }
        do { try await api.removeProjectLink(id: link.id) }
        catch { await load() }
    }

    private static let ymdOutput: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
}

/// Local draft state for the "Add Entry" finish-log form.
private struct FinishFormState {
    var productName = ""
    var finishType = ""
    var color = ""
    var coats = ""
    var notes = ""
    var appliedAt = Date()
}

// MARK: - Small shared pieces

/// A titled detail section with optional leading icon + trailing accessory.
private struct SectionBox<Content: View>: View {
    let title: String
    var icon: String? = nil
    var trailing: AnyView? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Theme.subtle) }
                Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                if let trailing { trailing }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
    }
}

private struct Stat: View {
    let icon: String, label: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.4)
            }
            .foregroundStyle(Theme.subtle).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wraps a URL so it can drive `.sheet(item:)`.
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private func money(_ n: Double) -> String { String(format: "$%.2f", n) }

private func formatDims(_ c: CutListItem) -> String {
    let parts = [c.length, c.width, c.thickness].compactMap { $0 }.filter { !$0.isEmpty }
    return parts.isEmpty ? "—" : parts.joined(separator: " × ")
}

private func finishMeta(_ e: FinishLogEntry) -> String {
    var parts: [String] = []
    if let ft = e.finishType { parts.append(ft.capitalized) }
    if let c = e.color { parts.append(c) }
    if let n = e.coats { parts.append("\(n) coat\(n == 1 ? "" : "s")") }
    if let notes = e.notes, !notes.isEmpty { parts.append(notes) }
    return parts.joined(separator: " · ")
}

private func finishColor(_ type: String) -> Color {
    switch type.lowercased() {
    case "stain": return Color(red: 0.545, green: 0.271, blue: 0.075)
    case "oil": return Color(red: 0.804, green: 0.522, blue: 0.247)
    case "wax": return Color(red: 0.824, green: 0.706, blue: 0.549)
    case "varnish": return Color(red: 0.722, green: 0.525, blue: 0.043)
    case "lacquer": return Color(red: 0.439, green: 0.502, blue: 0.565)
    case "sealant": return Color(red: 0.184, green: 0.310, blue: 0.310)
    case "primer": return Color(red: 0.663, green: 0.663, blue: 0.663)
    case "paint": return Color(red: 0.255, green: 0.412, blue: 0.882)
    default: return Color(red: 0.412, green: 0.412, blue: 0.412)
    }
}

// Immutable, read-only formatters (formatting is thread-safe); shared to avoid
// re-allocating one per row.
nonisolated(unsafe) private let isoParser = ISO8601DateFormatter()
nonisolated(unsafe) private let ymdParser: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
}()
nonisolated(unsafe) private let displayDate: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; f.locale = Locale(identifier: "en_US"); return f
}()

private func shortDate(_ raw: String) -> String {
    if let d = ymdParser.date(from: String(raw.prefix(10))) { return displayDate.string(from: d) }
    if let d = isoParser.date(from: raw) { return displayDate.string(from: d) }
    return raw
}

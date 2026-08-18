import SwiftUI
import PhotosUI
// JournalingSuggestions.framework ships only in the iOS device SDK — there is
// no Simulator variant at all, unlike VisionKit's DataScannerViewController
// (which builds everywhere and is merely non-functional in Simulator).
// Without this guard, every simulator build of this target — which is how
// this whole project is normally built and run — would fail outright.
// @preconcurrency because JournalingSuggestion isn't Sendable-audited, and it
// crosses from the (MainActor) picker closure into a plain async call.
#if canImport(JournalingSuggestions)
@preconcurrency import JournalingSuggestions
#endif
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
    @State private var trackingCuts = CutListActivityController.isTracking
    @State private var showEditForm = false
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var savedAsTemplate = false
    @State private var materialMutationTokens: [Int: UUID] = [:]
    @State private var loadGeneration = 0

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
                        metaCard(d).padding(.top, heroImage(d) != nil ? -70 : 20)
                        if !d.woodTypes.isEmpty || !d.toolsNeeded.isEmpty { chips(d).padding(.top, 28) }
                        buildNotesSection(d)
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
                    .contentColumn(900)
                }
                .padding(.bottom, 40)
            } else if loading {
                ProjectDetailSkeletonView()
            } else if let err = loadError {
                errorState(err)
            }
        }
        .boardBackground()
        .navigationTitle(d?.title ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if d != nil, !model.isDemoMode {
                ToolbarItem(placement: .topBarTrailing) {
                    BoardToolbarButton(symbol: "pencil", label: "Edit", tone: .amber) { showEditForm = true }
                }
                .boardToolbarItem()
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
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accentDeep)
                            .frame(width: 38, height: 38)
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Project actions")
                }
                .boardToolbarItem()
            }
        }
        .confirmationDialog("Delete this project?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteProject() } }
            Button("Cancel", role: .cancel) {}
        }
        .task { await load() }
        .refreshable { await load() }
        .fullScreenCover(item: $gallery) { ImageLightbox(preview: $0) }
        .sheet(item: $pdfURL) { PDFViewerSheet(url: $0.url) }
        .sheet(item: $exportURL) { ActivityShareSheet(items: [$0.url]) }
        .sheet(isPresented: $showEditForm) {
            ProjectFormView(api: api, projectId: projectId) { _ in
                Task { await load() }
            }
        }
        .userActivity(HandoffActivity.viewingProject, isActive: d != nil && !model.isDemoMode) { activity in
            guard let d else { return }
            activity.title = d.title
            activity.userInfo = [HandoffActivity.projectIdKey: projectId]
            activity.isEligibleForHandoff = true
        }
    }

    // MARK: Hero + meta

    @ViewBuilder private func hero(_ d: WSProjectDetail) -> some View {
        if let img = heroImage(d), let url = imageURL(img.id) {
            AuthImage(url: url, contentMode: .fill)
                .frame(height: 300).frame(maxWidth: .infinity).clipped()
                .overlay(
                    LinearGradient(colors: [.clear, Theme.concourse.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)
                )
        }
        // No placeholder slab when there is no hero image — an empty band of a
        // second surface colour reads as a loading failure, not as design.
    }

    private func metaCard(_ d: WSProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge(status: d.status)
            Text(d.title).font(Theme.display(28)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let desc = d.description, !desc.isEmpty {
                Text(descriptionParts(desc).summary)
                    .font(Theme.ui(15, .regular))
                    .foregroundStyle(Theme.muted)
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
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                Stat(icon: "gauge.medium", label: "Difficulty", value: d.difficulty.rawValue.capitalized)
                Stat(icon: "clock", label: "Est. Hours", value: "\(d.estimatedHours)h")
                Stat(icon: "square.stack.3d.up", label: "Parts", value: "\(d.partsCount)")
                Stat(icon: "dollarsign.circle", label: "Est. Cost", value: money(d.totalCost))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .planGlass()
    }

    private func linkLabel(_ text: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12))
            Text(text).font(Theme.ui(14, .medium))
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

    @ViewBuilder private func buildNotesSection(_ d: WSProjectDetail) -> some View {
        if let description = d.description,
           let notes = descriptionParts(description).notes {
            SectionBox(title: "Build Notes", icon: "list.number") {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .planGlass(elevated: false)
            }
        }
    }

    private func descriptionParts(_ description: String) -> (summary: String, notes: String?) {
        guard let marker = description.range(
            of: "\\n\\s*1[\\.)]\\s",
            options: .regularExpression
        ) else {
            return (description, nil)
        }
        let summary = description[..<marker.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let notesStart = description.index(after: marker.lowerBound)
        let notes = description[notesStart...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (summary, notes.isEmpty ? nil : notes)
    }

    // MARK: Galleries

    @ViewBuilder private func sketchesSection(_ d: WSProjectDetail) -> some View {
        let sketches = d.images.filter { $0.kind == .sketch }
        if !sketches.isEmpty {
            let previewURLs = sketches.filter { !$0.isPDF }.compactMap { imageURL($0.id) }
            SectionBox(title: "Sketches & Plans") {
                imageGrid {
                    ForEach(Array(sketches.enumerated()), id: \.element.id) { index, img in
                        if img.isPDF {
                            Button { if let u = imageURL(img.id) { pdfURL = IdentifiableURL(url: u) } } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: "doc.text.fill").font(.system(size: 32)).foregroundStyle(Theme.accent)
                                    Text("Open PDF").font(Theme.ui(13, .medium)).foregroundStyle(Theme.ink)
                                }
                                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                .background(
                                    Theme.flapShade,
                                    in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                                        .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open plan PDF \(index + 1)")
                        } else if let url = imageURL(img.id) {
                            Button { gallery = GalleryPreview(urls: previewURLs, index: previewURLs.firstIndex(of: url) ?? 0) } label: {
                                squareImageTile(url: url)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open sketch \(index + 1)")
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
                    ForEach(Array(inspiration.enumerated()), id: \.element.id) { index, img in
                        if let url = inspirationURL(img) {
                            Button { gallery = GalleryPreview(urls: urls, index: urls.firstIndex(of: url) ?? 0) } label: {
                                squareImageTile(url: url)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open inspiration image \(index + 1)")
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
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
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
                            .font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
                        if !model.isDemoMode {
                            Button {
                                Task {
                                    if trackingCuts {
                                        await CutListActivityController.end()
                                    } else {
                                        await CutListActivityController.start(projectId: d.id, projectTitle: d.title, cutList: d.cutList)
                                    }
                                    trackingCuts.toggle()
                                }
                            } label: {
                                Image(systemName: trackingCuts ? "checklist.checked" : "checklist").font(.system(size: 13))
                            }
                            .tint(trackingCuts ? Theme.accent : Theme.muted)
                            .minimumHitTarget()
                            .accessibilityLabel(trackingCuts ? "Stop tracking cuts" : "Track cuts")
                            .accessibilityValue(trackingCuts ? "On" : "Off")
                            .accessibilityAddTraits(trackingCuts ? .isSelected : [])
                        }
                        Button {
                            if let url = CSVExport.cutListCSV(d.cutList, projectTitle: d.title) {
                                exportURL = IdentifiableURL(url: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                        }
                        .minimumHitTarget()
                        .accessibilityLabel("Export cut list")
                       })) {
                VStack(spacing: 0) {
                    ForEach(Array(d.cutList.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider().overlay(Theme.line) }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(c.partName).font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                Text("×\(c.qty)").font(Theme.board(14, .semibold)).foregroundStyle(Theme.muted)
                            }
                            HStack(spacing: 6) {
                                Text(formatDims(c)).font(Theme.board(13, .regular)).foregroundStyle(Theme.muted)
                                if let m = c.material, !m.isEmpty {
                                    Text("· \(m)").font(Theme.ui(13, .medium)).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .background(Theme.flap)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                        .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Cut plan optimizer

    private func cutPlanSection(_ d: WSProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: showCutPlan ? 16 : 0) {
            HStack {
                Text("Cut Plan Optimizer").font(Theme.ui(18, .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button { showCutPlan.toggle() } label: {
                    Label(showCutPlan ? "Hide" : "Plan Cuts", systemImage: "scissors").font(Theme.ui(13, .regular))
                }
            }
            if showCutPlan {
                CutPlanOptimizerView(
                    api: api,
                    cutList: d.cutList,
                    projectId: model.isDemoMode ? nil : d.id
                )
            }
        }
        .padding(.top, 36)
    }

    // MARK: Materials

    @ViewBuilder private func materialsSection(_ d: WSProjectDetail) -> some View {
        if !d.materials.isEmpty {
            SectionBox(title: "Materials & Hardware",
                       trailing: AnyView(HStack(spacing: 10) {
                        Text("Total: \(money(d.totalCost))").font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
                        Button {
                            if let url = CSVExport.materialsCSV(d.materials, projectTitle: d.title) {
                                exportURL = IdentifiableURL(url: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                        }
                        .minimumHitTarget()
                        .accessibilityLabel("Export materials")
                       })) {
                VStack(spacing: 0) {
                    ForEach(Array(d.materials.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Divider().overlay(Theme.line) }
                        materialRow(m)
                    }
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

    @ViewBuilder private func materialRow(_ material: WSMaterial) -> some View {
        if model.isDemoMode {
            materialRowContent(material)
                .accessibilityElement(children: .combine)
                .accessibilityValue(material.purchased ? "Purchased" : "Not purchased")
                .accessibilityHint("Read-only demo")
        } else {
            Button { Task { await togglePurchased(material) } } label: {
                materialRowContent(material)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: material.purchased)
            .disabled(materialMutationTokens[material.id] != nil)
            .accessibilityElement(children: .combine)
            .accessibilityValue(material.purchased ? "Purchased" : "Not purchased")
            .accessibilityHint(material.purchased ? "Marks this material as not purchased" : "Marks this material as purchased")
            .accessibilityAddTraits(material.purchased ? [.isButton, .isSelected] : .isButton)
        }
    }

    private func materialRowContent(_ material: WSMaterial) -> some View {
        HStack(spacing: 14) {
            Image(systemName: material.purchased ? "checkmark.square.fill" : "square")
                .foregroundStyle(material.purchased ? Theme.accent : Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(material.name).font(Theme.ui(15, .medium))
                    .foregroundStyle(material.purchased ? Theme.muted : Theme.ink)
                    .strikethrough(material.purchased)
                if let quantity = material.qtyLabel, !quantity.isEmpty {
                    Text(quantity).font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            Text(money(material.cost)).font(Theme.board(14, .regular))
                .foregroundStyle(material.purchased ? Theme.muted : Theme.ink)
                .strikethrough(material.purchased)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: Finish log

    private static let finishTypes = ["Stain", "Oil", "Wax", "Varnish", "Lacquer", "Sealant", "Primer", "Paint", "Other"]

    @ViewBuilder private func finishLogSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Finish Log", icon: "drop.fill",
                   trailing: model.isDemoMode ? nil : AnyView(toggleButton(showFinishForm, "Add Entry") {
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
                                Text(e.productName).font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                                Text(finishMeta(e)).font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text(shortDate(e.appliedAt)).font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                            if !model.isDemoMode {
                                Button { Task { await deleteFinishEntry(e) } } label: {
                                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.muted)
                                }
                                .minimumHitTarget()
                                .accessibilityLabel("Delete \(e.productName) finish entry")
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
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
        .planGlass(elevated: false)
    }

    // MARK: Build log

    @ViewBuilder private func buildLogSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Build Log", icon: "book.closed.fill",
                   trailing: model.isDemoMode ? nil : AnyView(toggleButton(showBuildForm, "Add Note") {
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
                            Capsule().fill(Theme.accentDeep.opacity(0.62)).frame(width: 3)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(shortDate(e.createdAt)).font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                                if !e.note.isEmpty {
                                    Text(e.note).font(Theme.ui(14, .regular)).foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if e.hasPhoto, let url = buildLogURL(e.id) {
                                    Button { gallery = GalleryPreview(urls: [url], index: 0) } label: {
                                        AuthImage(url: url, contentMode: .fill)
                                            .frame(maxWidth: 260).frame(height: 180).clipped()
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: Theme.rPanel,
                                                    style: .continuous
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Open build photo from \(shortDate(e.createdAt))")
                                }
                            }
                            Spacer(minLength: 0)
                            if !model.isDemoMode {
                                Button { Task { await deleteBuildEntry(e) } } label: {
                                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.muted)
                                }
                                .minimumHitTarget()
                                .accessibilityLabel("Delete build entry from \(shortDate(e.createdAt))")
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .planGlass(elevated: false)
                    }
                }
            }
        }
    }

    private func buildAddForm() -> some View {
        let buildPhotoLabel = buildPhotoData == nil ? "Attach photo" : "Photo attached"

        return VStack(alignment: .leading, spacing: 10) {
            TextField("Cut all the legs to length… First coat looks great…", text: $buildNote, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                PhotosPicker(selection: $buildPhotoItem, matching: .images) {
                    Label(buildPhotoLabel, systemImage: "camera")
                }
                .onChange(of: buildPhotoItem) { _, item in
                    Task {
                        if let item, let data = try? await item.loadTransferable(type: Data.self) { buildPhotoData = data }
                    }
                }
                // A shop session is exactly the kind of "moment" the on-device
                // suggestions engine already tracks (photos taken in a burst,
                // at one location) — this is the read-only, user-initiated
                // direction of the API: picking a suggested moment to pull
                // its photo in, not donating Workshop's own data out to
                // Journal (JournalingSuggestions has no such API).
                #if canImport(JournalingSuggestions)
                if #available(iOS 17.2, *) {
                    JournalingSuggestionsPicker("From Journal") { suggestion in
                        await attachJournalingSuggestionPhoto(suggestion)
                    }
                }
                #endif
                if buildPhotoData != nil {
                    Button("Remove") { buildPhotoData = nil; buildPhotoItem = nil }
                        .font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
                }
            }
            .font(Theme.ui(14, .regular))
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
        .planGlass(elevated: false)
    }

    // MARK: Linked projects

    @ViewBuilder private func linksSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Linked Projects", icon: "link",
                   trailing: model.isDemoMode ? nil : AnyView(toggleButton(showLinkForm, "Link Project") {
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
                            Image(systemName: "link").font(.system(size: 12)).foregroundStyle(Theme.muted)
                            Text(link.linkedTitle).font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(link.relationship).font(Theme.ui(11, .regular)).foregroundStyle(Theme.muted)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.flapShade, in: RoundedRectangle(cornerRadius: Theme.rFlap))
                            StatusBadge(status: link.linkedStatus)
                            if !model.isDemoMode {
                                Button { Task { await removeLink(link) } } label: {
                                    Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.muted)
                                }
                                .minimumHitTarget()
                                .accessibilityLabel("Remove link to \(link.linkedTitle)")
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
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
        .planGlass(elevated: false)
    }

    private func toggleButton(_ shown: Bool, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(shown ? "Cancel" : label, systemImage: shown ? "chevron.up" : "plus")
                .font(Theme.ui(13, .regular))
        }
    }

    private var footer: some View {
        Text("Measure twice · Cut once")
            .font(Theme.ui(13)).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity).padding(.top, 40)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text("Couldn’t load project").font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(Theme.ink)
            Text(msg).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
        }.frame(maxWidth: .infinity).padding(.top, 80)
    }

    private func emptyNote(_ t: String) -> some View {
        Text(t).font(Theme.ui(14, .regular)).foregroundStyle(Theme.muted)
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
        loadGeneration &+= 1
        let generation = loadGeneration
        loading = d == nil; loadError = nil
        do {
            var refreshed = try await api.project(id: projectId)
            guard generation == loadGeneration else { return }
            let pendingValues = Dictionary(
                uniqueKeysWithValues: d?.materials.compactMap { material in
                    materialMutationTokens[material.id] == nil ? nil : (material.id, material.purchased)
                } ?? []
            )
            for index in refreshed.materials.indices {
                if let pending = pendingValues[refreshed.materials[index].id] {
                    refreshed.materials[index].purchased = pending
                }
            }
            d = refreshed
            rescheduleFinishReminders()
        }
        catch {
            guard generation == loadGeneration else { return }
            loadError = error.localizedDescription
        }
        loading = false
        if model.pendingShowCutPlan {
            showCutPlan = true
            model.pendingShowCutPlan = false
        }
    }

    /// Re-syncs every finish-log entry's "time for another coat" reminder
    /// (Phase 7.7) — cheap and idempotent (stable per-entry identifier), so
    /// it's simplest to just do this on every load rather than diff changes.
    private func rescheduleFinishReminders() {
        guard !model.isDemoMode, let d else { return }
        for entry in d.finishLog {
            FinishReminderScheduler.schedule(entry, projectTitle: d.title)
        }
    }

    // MARK: Materials — optimistic purchased toggle

    private func togglePurchased(_ m: WSMaterial) async {
        guard !model.isDemoMode,
              materialMutationTokens[m.id] == nil,
              let idx = d?.materials.firstIndex(where: { $0.id == m.id })
        else { return }
        loadGeneration &+= 1
        let token = UUID()
        materialMutationTokens[m.id] = token
        let previous = d?.materials[idx].purchased ?? m.purchased
        let next = !previous
        d?.materials[idx].purchased = next
        do {
            try await api.setPurchased(id: m.id, purchased: next)
        } catch {
            if let current = d?.materials.firstIndex(where: { $0.id == m.id }) {
                d?.materials[current].purchased = previous
            }
            ToastCenter.shared.error("Could not update \(m.name)")
            Haptics.error()
        }
        guard materialMutationTokens[m.id] == token else { return }
        loadGeneration &+= 1
        materialMutationTokens[m.id] = nil
    }

    // MARK: Save as template / delete

    private func saveAsTemplate() async {
        guard !model.isDemoMode, let d else { return }
        do {
            _ = try await api.saveAsTemplate(projectId: d.id, name: d.title)
            Haptics.success()
            ToastCenter.shared.success("Saved as template")
            savedAsTemplate = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            savedAsTemplate = false
        } catch {
            ToastCenter.shared.error("Could not save template")
        }
    }

    private func deleteProject() async {
        guard !model.isDemoMode else { return }
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
        guard !model.isDemoMode else { return }
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
            ToastCenter.shared.success("Finish entry saved")
            FinishReminderScheduler.requestAuthorizationIfNeeded()
            await load()
            finishForm = FinishFormState()
            showFinishForm = false
        } catch {
            ToastCenter.shared.error("Could not save entry")
        }
        finishSaving = false
    }

    private func deleteFinishEntry(_ e: FinishLogEntry) async {
        guard !model.isDemoMode else { return }
        d?.finishLog.removeAll { $0.id == e.id }
        FinishReminderScheduler.cancel(e)
        do {
            try await api.deleteFinishLogEntry(id: e.id)
            ToastCenter.shared.success("Entry deleted")
        } catch { await load() }
    }

    // MARK: Build log

    /// Pulls the first photo out of a picked Journaling Suggestion moment and
    /// drops it into the same `buildPhotoData` the PhotosPicker attach button
    /// fills — `addBuildEntry()` doesn't need to know which source it came
    /// from.
    #if canImport(JournalingSuggestions)
    @available(iOS 17.2, *)
    private func attachJournalingSuggestionPhoto(_ suggestion: JournalingSuggestion) async {
        let photos = await suggestion.content(forType: JournalingSuggestion.Photo.self)
        guard let url = photos.first?.photo else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        buildPhotoData = data
    }
    #endif

    private func addBuildEntry() async {
        guard !model.isDemoMode, let projectId = d?.id else { return }
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
            ToastCenter.shared.success("Build note saved")
            buildNote = ""; buildPhotoData = nil; buildPhotoItem = nil; buildUploadProgress = nil
            showBuildForm = false
        } catch {
            ToastCenter.shared.error("Could not save note")
        }
        buildSaving = false
    }

    private func deleteBuildEntry(_ e: BuildLogEntry) async {
        guard !model.isDemoMode else { return }
        d?.buildLog.removeAll { $0.id == e.id }
        do {
            try await api.deleteBuildLogEntry(id: e.id)
            ToastCenter.shared.success("Note deleted")
        } catch { await load() }
    }

    // MARK: Linked projects

    private func loadAllProjects() async {
        guard allProjects.isEmpty else { return }
        allProjects = (try? await api.listProjects()) ?? []
    }

    private func addLink() async {
        guard !model.isDemoMode, let linkProjectId, let projectId = d?.id else { return }
        linkSaving = true
        do {
            try await api.addProjectLink(projectId: projectId, linkedProjectId: linkProjectId, relationship: linkRelationship)
            Haptics.success()
            ToastCenter.shared.success("Project linked")
            await load()
            self.linkProjectId = nil; showLinkForm = false
        } catch {
            ToastCenter.shared.error("Could not link project")
        }
        linkSaving = false
    }

    private func removeLink(_ link: ProjectLink) async {
        guard !model.isDemoMode else { return }
        d?.links.removeAll { $0.id == link.id }
        do {
            try await api.removeProjectLink(id: link.id)
            ToastCenter.shared.success("Link removed")
        } catch { await load() }
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
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accentDeep)
                }
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
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
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Theme.flapShade.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
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
private let ymdParser: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
}()
private let displayDate: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; f.locale = Locale(identifier: "en_US"); return f
}()

private func shortDate(_ raw: String) -> String {
    if let d = ymdParser.date(from: String(raw.prefix(10))) { return displayDate.string(from: d) }
    if let d = isoParser.date(from: raw) { return displayDate.string(from: d) }
    return raw
}

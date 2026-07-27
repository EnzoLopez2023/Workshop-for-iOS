import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import NintekKit

/// Create/edit a project — parity with `ProjectForm.tsx`: all top-level
/// fields, status/difficulty pickers, wood/tools tag editors, cut-list +
/// materials row editors with native `List` reordering (replaces the web's
/// dnd-kit) that persists `sort_order` per row on move, photo/PDF uploads
/// (PhotosPicker + camera + Files, sketch/inspiration kinds, add-by-URL,
/// delete) with progress cards, and "Analyze with AI" (Phase 5.1).
struct ProjectFormView: View {
    let api: WorkshopAPI
    /// nil = create a new project; non-nil = edit that project.
    let projectId: Int?
    /// Called with the saved project's id once create/update + row sync succeed.
    let onSaved: (Int) -> Void

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var sourceUrl = ""
    @State private var cutPlanUrl = ""
    @State private var description = ""
    @State private var status: ProjectStatus = .idea
    @State private var difficulty: Difficulty = .intermediate
    @State private var estimatedHours = 0
    @State private var woodInput = ""
    @State private var toolsInput = ""
    @State private var sketches: [WSImage] = []
    @State private var inspiration: [WSImage] = []
    @State private var cutRows: [CutRowDraft] = []
    @State private var scanningRowID: UUID?
    @State private var matRows: [MaterialRowDraft] = []

    @State private var loading: Bool
    @State private var loadError: String?
    @State private var saving = false
    @State private var saveError: String?
    @State private var analyzing = false
    @State private var analyzeError: String?

    // Uploads
    @State private var uploads: [UploadEntry] = []
    @State private var sketchPickerItems: [PhotosPickerItem] = []
    @State private var inspirationPickerItems: [PhotosPickerItem] = []
    @State private var showSketchCamera = false
    @State private var showInspirationCamera = false
    @State private var showSketchCanvas = false
    @State private var showPDFImporter = false
    @State private var showInspirationURLField = false
    @State private var inspirationURLInput = ""

    private var editing: Bool { projectId != nil }

    init(api: WorkshopAPI, projectId: Int?, onSaved: @escaping (Int) -> Void) {
        self.api = api; self.projectId = projectId; self.onSaved = onSaved
        _loading = State(initialValue: projectId != nil)
        if projectId == nil {
            let raw = UserDefaults.standard.string(forKey: SettingsKeys.defaultProjectStatus)
            _status = State(initialValue: ProjectStatus(rawValue: raw ?? "") ?? .idea)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 8) {
                        Text("Couldn’t load project").font(.headline)
                        Text(err).font(.footnote).foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadExisting() } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    form
                }
            }
            .overlay(alignment: .bottomTrailing) {
                UploadProgressPanel(uploads: uploads) { id in uploads.removeAll { $0.id == id } }
                    .padding(16)
            }
            .creamBackground()
            .navigationTitle(editing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task { if editing { await loadExisting() } }
            .sheet(isPresented: Binding(
                get: { scanningRowID != nil },
                set: { if !$0 { scanningRowID = nil } }
            )) {
                if let idx = cutRows.firstIndex(where: { $0.id == scanningRowID }) {
                    DimensionScannerSheet(length: $cutRows[idx].length, width: $cutRows[idx].width, thickness: $cutRows[idx].thickness)
                }
            }
        }
    }

    // MARK: Form

    private var form: some View {
        List {
            Section {
                TextField("Title", text: $title)
                TextField("Plans URL", text: $sourceUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button { Task { await analyze() } } label: {
                    if analyzing {
                        Label("Analyzing…", systemImage: "sparkles")
                    } else {
                        Label("Analyze with AI", systemImage: "sparkles")
                    }
                }
                .disabled(analyzing || sourceUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                if let analyzeError {
                    Text(analyzeError).font(.footnote).foregroundStyle(Theme.fail)
                }
                TextField("OptiCutter Cut Plan URL", text: $cutPlanUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Description & notes", text: $description, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("Details")
            } footer: {
                Text("AI fills in title, description, cut list & materials from the plans URL.")
            }

            Section("Status & Estimate") {
                Picker("Status", selection: $status) {
                    ForEach(Self.statuses, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Self.difficulties, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Stepper("Est. Hours: \(estimatedHours)", value: $estimatedHours, in: 0...500)
            }

            Section("Materials Tags") {
                TextField("Wood types (comma-separated)", text: $woodInput)
                TextField("Tools needed (comma-separated)", text: $toolsInput)
            }

            if let projectId {
                Section {
                    if sketches.isEmpty {
                        Text("No sketches yet.").foregroundStyle(.secondary).font(.footnote)
                    } else {
                        imageStrip(sketches, kind: .sketch)
                    }
                    uploadButtons(kind: .sketch, projectId: projectId, allowPDF: true)
                } header: {
                    Text("Sketches & Plans")
                }
                Section {
                    if inspiration.isEmpty {
                        Text("No inspiration images yet.").foregroundStyle(.secondary).font(.footnote)
                    } else {
                        imageStrip(inspiration, kind: .inspiration)
                    }
                    uploadButtons(kind: .inspiration, projectId: projectId, allowPDF: false)
                    if showInspirationURLField {
                        HStack {
                            TextField("https://…", text: $inspirationURLInput)
                                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("Add") { Task { await addInspirationURL(projectId: projectId) } }
                                .disabled(inspirationURLInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button { showInspirationURLField = true } label: {
                            Label("Add by URL", systemImage: "link")
                        }
                    }
                } header: {
                    Text("Inspiration")
                }
            } else {
                Section {
                    Text("Save the project first to add sketches, inspiration, and photos.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                if cutRows.isEmpty {
                    Text("No parts yet.").foregroundStyle(.secondary).font(.footnote)
                }
                ForEach($cutRows) { $row in
                    cutRowEditor(row: $row)
                }
                .onDelete { offsets in deleteCutRows(at: offsets) }
                .onMove { from, to in
                    cutRows.move(fromOffsets: from, toOffset: to)
                    persistCutOrder()
                }
                Button { addCutRow() } label: {
                    Label("Add Part", systemImage: "plus")
                }
            } header: {
                Text("Cut List")
            } footer: {
                Text("Every piece you'll need to mill.")
            }

            Section {
                if matRows.isEmpty {
                    Text("No materials yet.").foregroundStyle(.secondary).font(.footnote)
                }
                ForEach($matRows) { $row in
                    materialRowEditor(row: $row)
                }
                .onDelete { offsets in deleteMatRows(at: offsets) }
                .onMove { from, to in
                    matRows.move(fromOffsets: from, toOffset: to)
                    persistMatOrder()
                }
                Button { addMatRow() } label: {
                    Label("Add Material", systemImage: "plus")
                }
            } header: {
                Text("Materials & Hardware")
            } footer: {
                Text("Screws, glue, finish, and everything else.")
            }

            if let saveError {
                Section {
                    Text(saveError).font(.footnote).foregroundStyle(Theme.fail)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
    }

    // MARK: Row editors

    private func cutRowEditor(row: Binding<CutRowDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Part name", text: row.partName)
                    .font(.system(size: 15, weight: .medium))
                Button {
                    scanningRowID = row.wrappedValue.id
                } label: {
                    Image(systemName: "camera.viewfinder").font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }
            HStack(spacing: 8) {
                TextField("Qty", value: row.qty, format: .number)
                    .keyboardType(.numberPad).frame(width: 50)
                TextField("Length", text: row.length).frame(maxWidth: .infinity)
                TextField("Width", text: row.width).frame(maxWidth: .infinity)
                TextField("Thick.", text: row.thickness).frame(maxWidth: .infinity)
            }
            .font(.system(size: 13)).textFieldStyle(.roundedBorder)
            TextField("Material", text: row.material)
                .font(.system(size: 13)).textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }

    private func materialRowEditor(row: Binding<MaterialRowDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    row.wrappedValue.purchased.toggle()
                } label: {
                    Image(systemName: row.wrappedValue.purchased ? "checkmark.square.fill" : "square")
                        .foregroundStyle(row.wrappedValue.purchased ? Theme.accent : Theme.subtle)
                }
                .buttonStyle(.plain)
                TextField("Name", text: row.name).font(.system(size: 15, weight: .medium))
            }
            HStack(spacing: 8) {
                TextField("Qty (e.g. 4 pcs, 1 quart)", text: row.qtyLabel)
                TextField("Cost", value: row.cost, format: .number).keyboardType(.decimalPad).frame(width: 80)
            }
            .font(.system(size: 13)).textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }

    private func imageStrip(_ images: [WSImage], kind: ImageKind) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images) { img in
                    let url = model.userKey.map { api.imageURL(imageId: img.id, userKey: $0) }
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if img.isPDF {
                                ZStack { Theme.creamSoft; Image(systemName: "doc.text.fill").foregroundStyle(Theme.accent) }
                            } else {
                                AuthImage(url: url, contentMode: .fill)
                            }
                        }
                        .frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: 10))

                        Button { Task { await removeImage(img, kind: kind) } } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(.black.opacity(0.65), in: Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.top, 6).padding(.trailing, 6)
        }
    }

    /// Upload row: PhotosPicker (multi-select), Camera (if available), Files (PDF, sketches only).
    private func uploadButtons(kind: ImageKind, projectId: Int, allowPDF: Bool) -> some View {
        HStack(spacing: 16) {
            PhotosPicker(
                selection: kind == .sketch ? $sketchPickerItems : $inspirationPickerItems,
                matching: .images
            ) {
                Label("Upload", systemImage: "photo.on.rectangle")
            }
            .onChange(of: kind == .sketch ? sketchPickerItems : inspirationPickerItems) { _, items in
                Task { await handlePickerSelection(items, kind: kind, projectId: projectId) }
            }

            if CameraPicker.isAvailable {
                Button {
                    if kind == .sketch { showSketchCamera = true } else { showInspirationCamera = true }
                } label: {
                    Label("Camera", systemImage: "camera")
                }
            }

            if allowPDF {
                Button { showPDFImporter = true } label: {
                    Label("PDF", systemImage: "doc.badge.plus")
                }
            }

            // Draw directly with Apple Pencil (Phase 7.4) — an alternative to
            // photographing a paper sketch. iPad only, matching the plan.
            if kind == .sketch, UIDevice.current.userInterfaceIdiom == .pad {
                Button { showSketchCanvas = true } label: {
                    Label("Draw", systemImage: "pencil.tip.crop.circle")
                }
            }
        }
        .font(.system(size: 14))
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .sheet(isPresented: kind == .sketch ? $showSketchCamera : $showInspirationCamera) {
            CameraPicker { image in
                Task { await uploadCameraImage(image, kind: kind, projectId: projectId) }
            }
        }
        .fileImporter(isPresented: allowPDF ? $showPDFImporter : .constant(false),
                     allowedContentTypes: [.pdf]) { result in
            Task { await handlePDFImport(result, projectId: projectId) }
        }
        .sheet(isPresented: kind == .sketch ? $showSketchCanvas : .constant(false)) {
            SketchCanvasSheet { data in
                Task {
                    await uploadImageData(data, kind: .sketch, projectId: projectId,
                                         filename: "sketch-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg")
                }
            }
        }
    }

    // MARK: Row mutation (matches the web's immediate-delete / local-add pattern)

    private func addCutRow() { cutRows.append(CutRowDraft()) }
    private func addMatRow() { matRows.append(MaterialRowDraft()) }

    private func deleteCutRows(at offsets: IndexSet) {
        let toDelete = offsets.map { cutRows[$0] }
        cutRows.remove(atOffsets: offsets)
        for row in toDelete {
            guard let sid = row.serverId else { continue }
            Task { try? await api.deleteCutItem(id: sid) }
        }
    }
    private func deleteMatRows(at offsets: IndexSet) {
        let toDelete = offsets.map { matRows[$0] }
        matRows.remove(atOffsets: offsets)
        for row in toDelete {
            guard let sid = row.serverId else { continue }
            Task { try? await api.deleteMaterial(id: sid) }
        }
    }

    /// After a drag reorder, push the new `sort_order` to every already-saved
    /// row (fire-and-forget, matching the web's `.catch(() => {})`). New rows
    /// (no serverId) get their order for free when they're created on Save.
    private func persistCutOrder() {
        for (idx, row) in cutRows.enumerated() {
            guard let sid = row.serverId else { continue }
            let item = CutListInput(partName: row.partName, qty: row.qty,
                                    length: row.length, width: row.width,
                                    thickness: row.thickness, material: row.material, sortOrder: idx)
            Task { try? await api.updateCutItem(id: sid, item) }
        }
    }
    private func persistMatOrder() {
        for (idx, row) in matRows.enumerated() {
            guard let sid = row.serverId else { continue }
            let item = MaterialInput(name: row.name, qtyLabel: row.qtyLabel, cost: row.cost,
                                     purchased: row.purchased, sortOrder: idx)
            Task { try? await api.updateMaterial(id: sid, item) }
        }
    }

    // MARK: Uploads

    /// PhotosPicker selection → re-encode each to JPEG (avoids HEIC handling on
    /// the server) → upload → refresh the image lists from the server (WSImage
    /// has no public initializer, so this is simpler than hand-building rows).
    private func handlePickerSelection(_ items: [PhotosPickerItem], kind: ImageKind, projectId: Int) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpeg = uiImage.jpegData(compressionQuality: 0.85) else { continue }
            await uploadImageData(jpeg, kind: kind, projectId: projectId,
                                 filename: "photo-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg")
        }
        if kind == .sketch { sketchPickerItems = [] } else { inspirationPickerItems = [] }
    }

    private func uploadCameraImage(_ image: UIImage, kind: ImageKind, projectId: Int) async {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        await uploadImageData(jpeg, kind: kind, projectId: projectId,
                             filename: "camera-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg")
    }

    private func handlePDFImport(_ result: Result<URL, Error>, projectId: Int) async {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        await uploadImageData(data, kind: .sketch, projectId: projectId,
                             filename: url.lastPathComponent, mimeType: "application/pdf")
    }

    private func uploadImageData(_ data: Data, kind: ImageKind, projectId: Int, filename: String, mimeType: String) async {
        let entryId = UUID()
        uploads.append(UploadEntry(id: entryId, name: filename, progress: 0, status: .uploading))
        do {
            let file = MultipartFile(filename: filename, mimeType: mimeType, data: data)
            try await api.uploadImage(projectId: projectId, kind: kind, file: file) { pct in
                Task { @MainActor in setUploadProgress(entryId, pct) }
            }
            setUploadStatus(entryId, .done)
            await refreshImages(projectId: projectId)
            scheduleUploadDismiss(entryId)
        } catch {
            setUploadStatus(entryId, .error, error: error.localizedDescription)
        }
    }

    private func addInspirationURL(projectId: Int) async {
        let url = inspirationURLInput.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        do {
            try await api.addInspirationURL(projectId: projectId, url: url)
            inspirationURLInput = ""; showInspirationURLField = false
            await refreshImages(projectId: projectId)
        } catch { /* silently ignore, matching the web's best-effort behavior */ }
    }

    private func removeImage(_ img: WSImage, kind: ImageKind) async {
        try? await api.deleteImage(id: img.id)
        if kind == .sketch { sketches.removeAll { $0.id == img.id } }
        else { inspiration.removeAll { $0.id == img.id } }
    }

    private func refreshImages(projectId: Int) async {
        guard let d = try? await api.project(id: projectId) else { return }
        sketches = d.images.filter { $0.kind == .sketch }
        inspiration = d.images.filter { $0.kind == .inspiration }
    }

    @MainActor private func setUploadProgress(_ id: UUID, _ pct: Double) {
        if let idx = uploads.firstIndex(where: { $0.id == id }) { uploads[idx].progress = pct }
    }
    private func setUploadStatus(_ id: UUID, _ status: UploadEntry.Status, error: String? = nil) {
        if let idx = uploads.firstIndex(where: { $0.id == id }) {
            uploads[idx].status = status; uploads[idx].error = error
            if status == .done { uploads[idx].progress = 1 }
        }
    }
    private func scheduleUploadDismiss(_ id: UUID) {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            uploads.removeAll { $0.id == id }
        }
    }

    // MARK: Load (edit mode)

    private func loadExisting() async {
        guard let projectId else { return }
        loading = true; loadError = nil
        do {
            let d = try await api.project(id: projectId)
            title = d.title
            description = d.description ?? ""
            sourceUrl = d.sourceUrl ?? ""
            cutPlanUrl = d.cutPlanUrl ?? ""
            status = d.status == .unknown ? .idea : d.status
            difficulty = d.difficulty == .unknown ? .intermediate : d.difficulty
            estimatedHours = d.estimatedHours
            woodInput = d.woodTypes.joined(separator: ", ")
            toolsInput = d.toolsNeeded.joined(separator: ", ")
            sketches = d.images.filter { $0.kind == .sketch }
            inspiration = d.images.filter { $0.kind == .inspiration }
            cutRows = d.cutList.map(CutRowDraft.init)
            matRows = d.materials.map(MaterialRowDraft.init)
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    // MARK: Analyze with AI

    /// Prefills empty fields and appends AI-suggested cut/material rows,
    /// matching the web's "only overwrite what the user hasn't touched" rule.
    private func analyze() async {
        let url = sourceUrl.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        guard url.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) != nil else {
            analyzeError = "URL must start with http:// or https://"
            return
        }
        analyzeError = nil
        analyzing = true
        do {
            let data = try await api.analyzeProjectURL(url)

            if title.trimmingCharacters(in: .whitespaces).isEmpty { title = data.title }
            if description.trimmingCharacters(in: .whitespaces).isEmpty { description = data.description }
            difficulty = data.difficulty
            if estimatedHours == 0 { estimatedHours = data.estimatedHours }
            if !data.woodTypes.isEmpty, woodInput.trimmingCharacters(in: .whitespaces).isEmpty {
                woodInput = data.woodTypes.joined(separator: ", ")
            }
            if !data.toolsNeeded.isEmpty, toolsInput.trimmingCharacters(in: .whitespaces).isEmpty {
                toolsInput = data.toolsNeeded.joined(separator: ", ")
            }
            for row in data.cutList {
                var draft = CutRowDraft()
                draft.partName = row.partName; draft.qty = row.qty == 0 ? 1 : row.qty
                draft.length = row.length ?? ""; draft.width = row.width ?? ""
                draft.thickness = row.thickness ?? ""; draft.material = row.material ?? ""
                cutRows.append(draft)
            }
            for row in data.materials {
                var draft = MaterialRowDraft()
                draft.name = row.name; draft.qtyLabel = row.qtyLabel ?? ""
                matRows.append(draft)
            }
            ToastCenter.shared.success("Fields pre-filled — review before saving")
        } catch {
            ToastCenter.shared.error("AI analysis failed")
            analyzeError = "Could not analyze: \(error.localizedDescription)"
        }
        analyzing = false
    }

    // MARK: Save

    private func save() async {
        saving = true; saveError = nil
        do {
            let input = ProjectInput(
                title: title, description: description, sourceUrl: sourceUrl, cutPlanUrl: cutPlanUrl,
                status: status, difficulty: difficulty, estimatedHours: estimatedHours,
                woodTypes: csvToArr(woodInput), toolsNeeded: csvToArr(toolsInput)
            )
            let savedId: Int
            if let projectId {
                savedId = try await api.updateProject(id: projectId, input).id
            } else {
                savedId = try await api.createProject(input).id
            }

            for row in cutRows {
                guard !row.partName.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let item = CutListInput(partName: row.partName, qty: row.qty,
                                        length: nilIfEmpty(row.length), width: nilIfEmpty(row.width),
                                        thickness: nilIfEmpty(row.thickness), material: nilIfEmpty(row.material))
                if let sid = row.serverId {
                    try await api.updateCutItem(id: sid, item)
                } else {
                    try await api.addCutItem(projectId: savedId, item)
                }
            }
            for row in matRows {
                guard !row.name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let item = MaterialInput(name: row.name, qtyLabel: nilIfEmpty(row.qtyLabel),
                                         cost: row.cost, purchased: row.purchased)
                if let sid = row.serverId {
                    try await api.updateMaterial(id: sid, item)
                } else {
                    try await api.addMaterial(projectId: savedId, item)
                }
            }

            Haptics.success()
            onSaved(savedId)
            dismiss()
        } catch {
            Haptics.error()
            saveError = "Could not save: \(error.localizedDescription)"
        }
        saving = false
    }

    private static let statuses: [ProjectStatus] = [.idea, .planning, .inProgress, .completed]
    private static let difficulties: [Difficulty] = [.beginner, .intermediate, .advanced]
}

// MARK: - Row drafts

private struct CutRowDraft: Identifiable {
    let id = UUID()
    var serverId: Int?
    var partName = ""
    var qty = 1
    var length = ""
    var width = ""
    var thickness = ""
    var material = ""

    init() {}
    init(from item: CutListItem) {
        serverId = item.id; partName = item.partName; qty = item.qty
        length = item.length ?? ""; width = item.width ?? ""
        thickness = item.thickness ?? ""; material = item.material ?? ""
    }
}

private struct MaterialRowDraft: Identifiable {
    let id = UUID()
    var serverId: Int?
    var name = ""
    var qtyLabel = ""
    var cost: Double = 0
    var purchased = false

    init() {}
    init(from item: WSMaterial) {
        serverId = item.id; name = item.name; qtyLabel = item.qtyLabel ?? ""
        cost = item.cost; purchased = item.purchased
    }
}

private func csvToArr(_ s: String) -> [String] {
    s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}
private func nilIfEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }

import SwiftUI
import PhotosUI
import NintekKit

/// Create/edit a Shaper Hub project — parity with `ShaperProjectForm.tsx`:
/// Shaper Hub URL + "Analyze with AI" (Phase 5.1), title, description, photo
/// upload + URL override with live preview, materials rows, optional cut-list
/// rows, instructions. Photos upload immediately in edit mode; in create mode
/// they're queued locally and uploaded right after the project is created
/// (matches the web's `queuedFiles`/`queuedImageUrls` pattern — the route
/// needs an id that doesn't exist yet).
struct ShaperProjectFormView: View {
    let api: WorkshopAPI
    let shaperId: Int?
    let onSaved: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    @State private var shaperUrl = ""
    @State private var title = ""
    @State private var description = ""
    @State private var photoUrl = ""
    @State private var materials: [MatRowDraft] = [MatRowDraft()]
    @State private var instructions = ""
    @State private var cutRows: [ShaperCutRowDraft] = []
    @State private var scanningRowID: UUID?

    // Photos
    @State private var existingImages: [WSImage] = []
    @State private var queuedPhotos: [Data] = []
    @State private var queuedImageURLs: [String] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadStatus: String?
    @State private var failedPhotoUploads: [Data] = []
    @State private var unresolvedPhotoReadFailures = 0
    @State private var uploadFailed = false
    @State private var uploadingPhotos = false

    @State private var loading: Bool
    @State private var loadError: String?
    @State private var saving = false
    @State private var saveError: String?
    /// The id `save()` created before it failed part-way — see the matching
    /// note in `ProjectFormView`. Retrying resumes that project rather than
    /// creating a second copy of it.
    @State private var createdShaperId: Int?
    @State private var analyzing = false
    @State private var analyzeError: String?

    private var editing: Bool { shaperId != nil }

    init(api: WorkshopAPI, shaperId: Int?, onSaved: @escaping (Int) -> Void) {
        self.api = api; self.shaperId = shaperId; self.onSaved = onSaved
        _loading = State(initialValue: shaperId != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 8) {
                        Text("Couldn’t load project").font(Theme.ui(17, .bold, relativeTo: .headline))
                        Text(err).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadExisting() } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    form
                }
            }
            .boardBackground()
            .navigationTitle(editing ? "Edit Shaper Project" : "New Shaper Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                .boardToolbarItem()
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty
                                 || shaperUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .boardToolbarItem()
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

    private var form: some View {
        let photoPickerLabel = uploadingPhotos ? "Uploading…" : "Upload Photos"

        return List {
            Section {
                TextField("Shaper Hub URL", text: $shaperUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button { Task { await analyze() } } label: {
                    Label(analyzing ? "Analyzing…" : "Analyze with AI", systemImage: "sparkles")
                }
                .disabled(analyzing || shaperUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                if let analyzeError {
                    Text(analyzeError).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.red)
                }
            } header: {
                Text("Shaper Hub URL")
            } footer: {
                Text("Paste a Shaper Tools Hub share URL and let AI fill in the details.")
            }

            Section("Title") {
                TextField("Project name", text: $title)
            }

            Section("Description") {
                TextField("What are you building?", text: $description, axis: .vertical).lineLimit(3...6)
            }

            Section("Photos") {
                if !existingImages.isEmpty {
                    imageStrip
                }
                if !queuedPhotos.isEmpty {
                    Text("\(queuedPhotos.count) photo\(queuedPhotos.count == 1 ? "" : "s") queued — will upload on save")
                        .font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(.secondary)
                }
                if unresolvedPhotoReadFailures > 0 {
                    Text(photoReadFailureMessage(unresolvedPhotoReadFailures))
                        .font(Theme.ui(13, .regular, relativeTo: .footnote))
                        .foregroundStyle(Theme.red)
                    Button("Dismiss Photo Error") {
                        unresolvedPhotoReadFailures = 0
                    }
                }
                if let uploadStatus {
                    Text(uploadStatus)
                        .font(Theme.ui(13, .regular, relativeTo: .footnote))
                        .foregroundStyle(uploadFailed ? Theme.red : Theme.muted)
                }
                if editing, !failedPhotoUploads.isEmpty {
                    Button {
                        Task { await retryFailedPhotoUploads() }
                    } label: {
                        Label("Retry Failed Uploads", systemImage: "arrow.clockwise")
                    }
                    .disabled(uploadingPhotos)
                }
                PhotosPicker(selection: $pickerItems, matching: .images) {
                    Label(photoPickerLabel, systemImage: "photo.badge.plus")
                }
                .disabled(uploadingPhotos)
                .onChange(of: pickerItems) { _, items in Task { await handlePickerSelection(items) } }
            }

            Section {
                TextField("https://…", text: $photoUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                if let url = URL(string: photoUrl), !photoUrl.isEmpty {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Theme.flapShade
                    }
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            } header: {
                Text("Photo URL")
            } footer: {
                Text("Fallback shown when no uploaded photo is set.")
            }

            Section {
                ForEach($materials) { $row in
                    HStack {
                        TextField("e.g. ¾″ Baltic birch plywood", text: $row.name)
                        TextField("Qty", text: $row.qty).frame(width: 90)
                    }
                }
                .onDelete { offsets in
                    materials.remove(atOffsets: offsets)
                    if materials.isEmpty { materials = [MatRowDraft()] }
                }
                Button { materials.append(MatRowDraft()) } label: {
                    Label("Add Material", systemImage: "plus")
                }
            } header: {
                Text("Materials")
            }

            Section {
                if cutRows.isEmpty {
                    Text("No cut-list rows yet.").foregroundStyle(.secondary).font(Theme.ui(13, .regular, relativeTo: .footnote))
                }
                ForEach($cutRows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Part name (e.g. Side Panel)", text: $row.partName)
                                .font(Theme.ui(15, .medium))
                            Button {
                                scanningRowID = row.id
                            } label: {
                                Image(systemName: "camera.viewfinder").font(.system(size: 15))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                        }
                        HStack(spacing: 8) {
                            TextField("Qty", text: $row.qty).keyboardType(.numberPad).frame(width: 50)
                            TextField("Length", text: $row.length).frame(maxWidth: .infinity)
                            TextField("Width", text: $row.width).frame(maxWidth: .infinity)
                            TextField("Thick.", text: $row.thickness).frame(maxWidth: .infinity)
                        }
                        .font(Theme.ui(13, .regular)).textFieldStyle(.roundedBorder)
                        TextField("Material", text: $row.material)
                            .font(Theme.ui(13, .regular)).textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in deleteCutRows(at: offsets) }
                Button { cutRows.append(ShaperCutRowDraft()) } label: {
                    Label("Add Part", systemImage: "plus")
                }
            } header: {
                Text("Cut List")
            } footer: {
                Text("Optional — enables the Cut Plan Optimizer.")
            }

            Section("Instructions") {
                TextField("Step-by-step build instructions…", text: $instructions, axis: .vertical)
                    .lineLimit(6...16)
            }

            if let saveError {
                Section {
                    Text(saveError).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.red)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
    }

    private var imageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(existingImages) { img in
                    if let key = model.userKey {
                        AuthImage(url: api.imageURL(imageId: img.id, userKey: key), contentMode: .fill)
                            .frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }

    // MARK: Photo handling

    private func handlePickerSelection(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        uploadingPhotos = true
        uploadFailed = false
        defer {
            uploadingPhotos = false
            pickerItems = []
        }

        var preparedPhotos: [Data] = []
        var readFailures = 0
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data),
                      let converted = uiImage.jpegData(compressionQuality: 0.85)
                else {
                    readFailures += 1
                    continue
                }
                preparedPhotos.append(converted)
            } catch {
                readFailures += 1
            }
        }

        unresolvedPhotoReadFailures += readFailures

        guard let shaperId else {
            queuedPhotos.append(contentsOf: preparedPhotos)
            uploadStatus = nil
            return
        }

        let result = await uploadPhotoBatch(preparedPhotos, shaperId: shaperId)
        failedPhotoUploads.append(contentsOf: result.failed)
        var refreshed = true
        if result.uploaded > 0 {
            refreshed = await refreshImages(shaperId)
        }

        if !failedPhotoUploads.isEmpty {
            uploadFailed = true
            uploadStatus = "\(failedPhotoUploads.count) photo upload\(failedPhotoUploads.count == 1 ? " is" : "s are") waiting to retry."
        } else if !refreshed {
            uploadFailed = true
            uploadStatus = "Photos uploaded, but the photo list could not refresh. Reopen the project to see them."
        } else if result.uploaded > 0 {
            await showUploadSuccess(result.uploaded)
        }
    }

    private func retryFailedPhotoUploads() async {
        guard let shaperId, !failedPhotoUploads.isEmpty else { return }
        uploadingPhotos = true
        uploadFailed = false
        let retryPhotos = failedPhotoUploads
        failedPhotoUploads = []
        defer { uploadingPhotos = false }

        let result = await uploadPhotoBatch(retryPhotos, shaperId: shaperId)
        failedPhotoUploads = result.failed
        var refreshed = true
        if result.uploaded > 0 {
            refreshed = await refreshImages(shaperId)
        }

        if !failedPhotoUploads.isEmpty {
            uploadFailed = true
            uploadStatus = "\(failedPhotoUploads.count) photo upload\(failedPhotoUploads.count == 1 ? " is" : "s are") still waiting to retry."
        } else if !refreshed {
            uploadFailed = true
            uploadStatus = "Photos uploaded, but the photo list could not refresh. Reopen the project to see them."
        } else {
            await showUploadSuccess(result.uploaded)
        }
    }

    private func uploadPhotoBatch(_ photos: [Data], shaperId: Int) async -> (uploaded: Int, failed: [Data]) {
        var uploaded = 0
        var failed: [Data] = []
        for (index, jpeg) in photos.enumerated() {
            uploadStatus = "Uploading \(index + 1) of \(photos.count)…"
            do {
                let file = MultipartFile(filename: "photo-\(UUID().uuidString).jpg",
                                         mimeType: "image/jpeg", data: jpeg)
                try await api.uploadShaperImage(shaperProjectId: shaperId, file: file)
                uploaded += 1
            } catch {
                NSLog("[Workshop] Shaper photo upload failed: %@", String(describing: error))
                failed.append(jpeg)
            }
        }
        return (uploaded, failed)
    }

    private func refreshImages(_ shaperId: Int) async -> Bool {
        do {
            existingImages = try await api.shaperProject(id: shaperId).images
            return true
        } catch {
            NSLog("[Workshop] Could not refresh Shaper photos: %@", String(describing: error))
            ToastCenter.shared.error("Could not refresh project photos")
            return false
        }
    }

    private func showUploadSuccess(_ count: Int) async {
        guard count > 0 else {
            uploadStatus = nil
            return
        }
        let message = "\(count) photo\(count == 1 ? "" : "s") uploaded"
        uploadFailed = false
        uploadStatus = message
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if uploadStatus == message { uploadStatus = nil }
    }

    private func photoReadFailureMessage(_ count: Int) -> String {
        "\(count) selected photo\(count == 1 ? "" : "s") could not be read. Select \(count == 1 ? "it" : "them") again to retry."
    }

    // MARK: Cut rows

    private func deleteCutRows(at offsets: IndexSet) {
        let toDelete = offsets.map { cutRows[$0] }
        cutRows.remove(atOffsets: offsets)
        for row in toDelete {
            guard let sid = row.serverId else { continue }
            Task { try? await api.deleteCutItem(id: sid) }
        }
    }

    // MARK: Analyze with AI

    /// Prefills empty fields; materials are replaced wholesale (not appended)
    /// when the AI returns any, matching the web's behavior. Extra photo URLs
    /// beyond the primary photo are queued and attached on save.
    private func analyze() async {
        let url = shaperUrl.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        analyzeError = nil
        analyzing = true
        do {
            let data = try await api.analyzeShaperURL(url)
            if title.trimmingCharacters(in: .whitespaces).isEmpty, !data.title.isEmpty {
                title = data.title
            }
            if description.trimmingCharacters(in: .whitespaces).isEmpty, !data.description.isEmpty {
                description = data.description
            }
            let finalPhotoUrl = (photoUrl.trimmingCharacters(in: .whitespaces).isEmpty && !data.photoUrl.isEmpty)
                ? data.photoUrl : photoUrl
            if finalPhotoUrl != photoUrl { photoUrl = finalPhotoUrl }
            if !data.materials.isEmpty {
                materials = data.materials.map { MatRowDraft(name: $0.name, qty: $0.qty) }
            }
            if instructions.trimmingCharacters(in: .whitespaces).isEmpty, !data.instructions.isEmpty {
                instructions = data.instructions
            }
            if let imageUrls = data.imageUrls, !imageUrls.isEmpty {
                queuedImageURLs = imageUrls.filter { $0 != finalPhotoUrl }
            }
        } catch {
            analyzeError = error.localizedDescription
        }
        analyzing = false
    }

    // MARK: Load (edit mode)

    private func loadExisting() async {
        guard let shaperId else { return }
        loading = true; loadError = nil
        do {
            let p = try await api.shaperProject(id: shaperId)
            shaperUrl = p.shaperUrl; title = p.title
            description = p.description ?? ""; photoUrl = p.photoUrl ?? ""
            materials = p.materials.isEmpty ? [MatRowDraft()] : p.materials.map { MatRowDraft(name: $0.name, qty: $0.qty) }
            instructions = p.instructions ?? ""
            cutRows = p.cutList.map(ShaperCutRowDraft.init)
            existingImages = p.images
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    // MARK: Save

    private func save() async {
        saving = true; saveError = nil
        let matList = materials
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ShaperMaterial(name: $0.name, qty: $0.qty) }
        let input = ShaperProjectInput(
            title: title, shaperUrl: shaperUrl,
            description: nilIfEmpty(description), photoUrl: nilIfEmpty(photoUrl),
            materials: matList, instructions: nilIfEmpty(instructions)
        )
        do {
            let savedId: Int
            if let existing = shaperId ?? createdShaperId {
                savedId = try await api.updateShaperProject(id: existing, input).id
            } else {
                savedId = try await api.createShaperProject(input).id
                createdShaperId = savedId
            }

            // Drain both queues as they land: a retry after a mid-save failure
            // must not upload the photos that already made it a second time.
            while let data = queuedPhotos.first {
                let file = MultipartFile(filename: "photo-\(UUID().uuidString).jpg",
                                        mimeType: "image/jpeg", data: data)
                _ = try await api.uploadShaperImage(shaperProjectId: savedId, file: file)
                queuedPhotos.removeFirst()
            }
            while let url = queuedImageURLs.first {
                _ = try await api.addShaperImageURL(shaperProjectId: savedId, url: url)
                queuedImageURLs.removeFirst()
            }

            for idx in cutRows.indices {
                let row = cutRows[idx]
                guard !row.partName.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let item = CutListInput(partName: row.partName, qty: Int(row.qty) ?? 1,
                                        length: nilIfEmpty(row.length), width: nilIfEmpty(row.width),
                                        thickness: nilIfEmpty(row.thickness), material: nilIfEmpty(row.material))
                if let sid = row.serverId {
                    try await api.updateCutItem(id: sid, item)
                } else {
                    cutRows[idx].serverId = try await api.addShaperCutItem(shaperProjectId: savedId, item).id
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
}

// MARK: - Row drafts

private struct MatRowDraft: Identifiable {
    let id = UUID()
    var name = ""
    var qty = ""
}

private struct ShaperCutRowDraft: Identifiable {
    let id = UUID()
    var serverId: Int?
    var partName = ""
    var qty = "1"
    var length = ""
    var width = ""
    var thickness = ""
    var material = ""

    init() {}
    init(from item: CutListItem) {
        serverId = item.id; partName = item.partName; qty = String(item.qty)
        length = item.length ?? ""; width = item.width ?? ""
        thickness = item.thickness ?? ""; material = item.material ?? ""
    }
}

private func nilIfEmpty(_ s: String) -> String? {
    let t = s.trimmingCharacters(in: .whitespaces)
    return t.isEmpty ? nil : t
}

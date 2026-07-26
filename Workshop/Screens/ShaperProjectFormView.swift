import SwiftUI
import PhotosUI
import NintekKit

/// Create/edit a Shaper Hub project — parity with `ShaperProjectForm.tsx`
/// (non-AI scope): Shaper Hub URL, title, description, photo upload + URL
/// override with live preview, materials rows, optional cut-list rows,
/// instructions. Photos upload immediately in edit mode; in create mode they're
/// queued locally and uploaded right after the project is created (matches the
/// web's `queuedFiles` pattern — the route needs an id that doesn't exist yet).
///
/// Deliberately out of scope: AI "Analyze with URL" (Phase 5.1).
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

    // Photos
    @State private var existingImages: [WSImage] = []
    @State private var queuedPhotos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadStatus: String?

    @State private var loading: Bool
    @State private var loadError: String?
    @State private var saving = false
    @State private var saveError: String?

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
                        Text("Couldn’t load project").font(.headline)
                        Text(err).font(.footnote).foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadExisting() } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    form
                }
            }
            .creamBackground()
            .navigationTitle(editing ? "Edit Shaper Project" : "New Shaper Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty
                                 || shaperUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task { if editing { await loadExisting() } }
        }
    }

    private var form: some View {
        List {
            Section {
                TextField("Shaper Hub URL", text: $shaperUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: {
                Text("Shaper Hub URL")
            } footer: {
                Text("e.g. https://hub.shapertools.com/creators/…/shares/…")
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
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let uploadStatus {
                    Text(uploadStatus).font(.footnote).foregroundStyle(.secondary)
                }
                PhotosPicker(selection: $pickerItems, matching: .images) {
                    Label("Upload Photos", systemImage: "photo.badge.plus")
                }
                .onChange(of: pickerItems) { _, items in Task { await handlePickerSelection(items) } }
            }

            Section {
                TextField("https://…", text: $photoUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                if let url = URL(string: photoUrl), !photoUrl.isEmpty {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Theme.creamSoft
                    }
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    Text("No cut-list rows yet.").foregroundStyle(.secondary).font(.footnote)
                }
                ForEach($cutRows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Part name (e.g. Side Panel)", text: $row.partName)
                            .font(.system(size: 15, weight: .medium))
                        HStack(spacing: 8) {
                            TextField("Qty", text: $row.qty).keyboardType(.numberPad).frame(width: 50)
                            TextField("Length", text: $row.length).frame(maxWidth: .infinity)
                            TextField("Width", text: $row.width).frame(maxWidth: .infinity)
                            TextField("Thick.", text: $row.thickness).frame(maxWidth: .infinity)
                        }
                        .font(.system(size: 13)).textFieldStyle(.roundedBorder)
                        TextField("Material", text: $row.material)
                            .font(.system(size: 13)).textFieldStyle(.roundedBorder)
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
                    Text(saveError).font(.footnote).foregroundStyle(Theme.fail)
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
                            .frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: Photo handling

    private func handlePickerSelection(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpeg = uiImage.jpegData(compressionQuality: 0.85) else { continue }
            if let shaperId {
                uploadStatus = "Uploading…"
                do {
                    let file = MultipartFile(filename: "photo-\(Int(Date().timeIntervalSince1970)).jpg",
                                            mimeType: "image/jpeg", data: jpeg)
                    try await api.uploadShaperImage(shaperProjectId: shaperId, file: file)
                    uploadStatus = "Uploaded"
                    await refreshImages(shaperId)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    uploadStatus = nil
                } catch {
                    uploadStatus = "Upload failed: \(error.localizedDescription)"
                }
            } else {
                queuedPhotos.append(jpeg)
            }
        }
        pickerItems = []
    }

    private func refreshImages(_ shaperId: Int) async {
        guard let p = try? await api.shaperProject(id: shaperId) else { return }
        existingImages = p.images
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
            if let shaperId {
                savedId = try await api.updateShaperProject(id: shaperId, input).id
            } else {
                savedId = try await api.createShaperProject(input).id
            }

            for data in queuedPhotos {
                let file = MultipartFile(filename: "photo-\(Int(Date().timeIntervalSince1970)).jpg",
                                        mimeType: "image/jpeg", data: data)
                _ = try? await api.uploadShaperImage(shaperProjectId: savedId, file: file)
            }

            for row in cutRows {
                guard !row.partName.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let item = CutListInput(partName: row.partName, qty: Int(row.qty) ?? 1,
                                        length: nilIfEmpty(row.length), width: nilIfEmpty(row.width),
                                        thickness: nilIfEmpty(row.thickness), material: nilIfEmpty(row.material))
                if let sid = row.serverId {
                    try await api.updateCutItem(id: sid, item)
                } else {
                    try await api.addShaperCutItem(shaperProjectId: savedId, item)
                }
            }

            onSaved(savedId)
            dismiss()
        } catch {
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

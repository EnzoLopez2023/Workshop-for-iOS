import SwiftUI
import NintekKit

/// Create/edit a project — parity with `ProjectForm.tsx` (Phase 3.1 scope):
/// all top-level fields, status/difficulty pickers, wood/tools tag editors,
/// and cut-list + materials row editors with native `List` reordering
/// (replaces the web's dnd-kit) that persists `sort_order` per row on move.
///
/// Deliberately out of scope here (later phases): AI "Analyze with URL"
/// (Phase 5.1), photo/PDF upload (Phase 3.2 — existing images show read-only),
/// delete/save-as-template (Phase 3.3).
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
    @State private var matRows: [MaterialRowDraft] = []

    @State private var loading: Bool
    @State private var loadError: String?
    @State private var saving = false
    @State private var saveError: String?

    private var editing: Bool { projectId != nil }

    init(api: WorkshopAPI, projectId: Int?, onSaved: @escaping (Int) -> Void) {
        self.api = api; self.projectId = projectId; self.onSaved = onSaved
        _loading = State(initialValue: projectId != nil)
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
        }
    }

    // MARK: Form

    private var form: some View {
        List {
            Section("Details") {
                TextField("Title", text: $title)
                TextField("Plans URL", text: $sourceUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("OptiCutter Cut Plan URL", text: $cutPlanUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Description & notes", text: $description, axis: .vertical)
                    .lineLimit(3...8)
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

            if editing {
                Section("Sketches & Plans") {
                    if sketches.isEmpty {
                        Text("No sketches yet.").foregroundStyle(.secondary).font(.footnote)
                    } else {
                        imageStrip(sketches)
                    }
                    Text("Photo & PDF upload lands in a later update.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Inspiration") {
                    if inspiration.isEmpty {
                        Text("No inspiration images yet.").foregroundStyle(.secondary).font(.footnote)
                    } else {
                        imageStrip(inspiration)
                    }
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
            TextField("Part name", text: row.partName)
                .font(.system(size: 15, weight: .medium))
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

    private func imageStrip(_ images: [WSImage]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images) { img in
                    let url = model.userKey.map { api.imageURL(imageId: img.id, userKey: $0) }
                    Group {
                        if img.isPDF {
                            ZStack { Theme.creamSoft; Image(systemName: "doc.text.fill").foregroundStyle(Theme.accent) }
                        } else {
                            AuthImage(url: url, contentMode: .fill)
                        }
                    }
                    .frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: 10))
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

            onSaved(savedId)
            dismiss()
        } catch {
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

import SwiftUI
import NintekKit

/// Shaper project detail — parity with `ShaperProjectDetail.tsx`: photo hero
/// (uploaded image, else `photo_url`), title + CNC badge + Shaper Hub link,
/// About, Materials, Instructions, Photos gallery, cut list, edit + delete.
/// The cut-plan optimizer is deferred (Phase 4).
struct ShaperDetailView: View {
    let api: WorkshopAPI
    let shaperId: Int
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var p: ShaperProject?
    @State private var loading = true
    @State private var loadError: String?
    @State private var gallery: GalleryPreview?
    @State private var showEditForm = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var showCutPlan = false

    var body: some View {
        ScrollView {
            if let p {
                VStack(alignment: .leading, spacing: 28) {
                    hero(p)
                    titleRow(p)
                    if let desc = p.description, !desc.isEmpty { section("About This Project") {
                        Text(desc).font(Theme.ui(15, .regular)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } }
                    if !p.materials.isEmpty { materialsSection(p) }
                    if let ins = p.instructions, !ins.isEmpty { instructionsSection(ins) }
                    if p.images.count > 1 { photosSection(p) }
                    if !p.cutList.isEmpty {
                        cutListSection(p)
                        cutPlanSection(p)
                    }
                }
                .contentColumn(900)
                .padding(20)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
            } else if let err = loadError {
                VStack(spacing: 8) {
                    Text("Couldn’t load project").font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(Theme.ink)
                    Text(err).font(Theme.ui(13, .regular, relativeTo: .footnote)).foregroundStyle(Theme.muted)
                    Button("Retry") { Task { await load() } }
                }.frame(maxWidth: .infinity).padding(.top, 80)
            }
        }
        .boardBackground()
        .navigationTitle(p?.title ?? "Shaper")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if p != nil, !model.isDemoMode {
                ToolbarItem(placement: .topBarTrailing) {
                    BoardToolbarButton(symbol: "pencil", label: "Edit", tone: .amber) { showEditForm = true }
                }
                .boardToolbarItem()
                ToolbarItem(placement: .topBarTrailing) {
                    BoardToolbarButton(symbol: "trash", label: "Delete", tone: .danger) {
                        confirmDelete = true
                    }
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
        .sheet(isPresented: $showEditForm) {
            ShaperProjectFormView(api: api, shaperId: shaperId) { _ in
                Task { await load() }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder private func hero(_ p: ShaperProject) -> some View {
        if let url = heroURL(p) {
            Rectangle().fill(Theme.flapShade)
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay { AuthImage(url: url, contentMode: .fill, placeholderSymbol: "cpu") }
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private func titleRow(_ p: ShaperProject) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.onSteel)
                .frame(width: 38, height: 38)
                .background(Theme.steel, in: RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 6) {
                Text(p.title).font(Theme.display(24)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let u = URL(string: p.shaperUrl) {
                    Link(destination: u) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.forward.square").font(.system(size: 12))
                            Text("View on Shaper Hub").font(Theme.ui(13, .regular))
                        }.foregroundStyle(Theme.muted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func materialsSection(_ p: ShaperProject) -> some View {
        section("Materials") {
            VStack(spacing: 0) {
                ForEach(Array(p.materials.enumerated()), id: \.offset) { i, m in
                    if i > 0 { Divider().overlay(Theme.line) }
                    HStack {
                        Text(m.name).font(Theme.ui(15, .regular)).foregroundStyle(Theme.ink)
                        Spacer()
                        if !m.qty.isEmpty {
                            Text(m.qty).font(Theme.ui(13, .regular)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .background(Theme.flap).clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func instructionsSection(_ text: String) -> some View {
        section("Instructions") {
            Text(text).font(Theme.ui(14, .regular)).foregroundStyle(Theme.ink)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Theme.flap, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func photosSection(_ p: ShaperProject) -> some View {
        let urls = p.images.compactMap { imageURL(id: $0.id) }
        return section("Photos") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(Array(p.images.enumerated()), id: \.element.id) { index, img in
                    if let url = imageURL(id: img.id) {
                        Button { gallery = GalleryPreview(urls: urls, index: urls.firstIndex(of: url) ?? 0) } label: {
                            // A definite-size Color.clear square (via .fit) bounds the grid
                            // cell before AuthImage fills it — .fill mode directly on the
                            // image has an ambiguous proposed height inside a LazyVGrid and
                            // overflows into the next row otherwise.
                            Color.clear
                                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                                .overlay { AuthImage(url: url, contentMode: .fill).clipped() }
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Shaper project photo \(index + 1)")
                    }
                }
            }
        }
    }

    private func cutListSection(_ p: ShaperProject) -> some View {
        section("Cut List") {
            VStack(spacing: 0) {
                ForEach(Array(p.cutList.enumerated()), id: \.element.id) { i, c in
                    if i > 0 { Divider().overlay(Theme.line) }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(c.partName).font(Theme.ui(15, .medium)).foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Text("×\(c.qty)").font(Theme.board(14, .semibold)).foregroundStyle(Theme.muted)
                        }
                        HStack(spacing: 6) {
                            Text(dims(c)).font(Theme.board(13, .regular)).foregroundStyle(Theme.muted)
                            if let m = c.material, !m.isEmpty {
                                Text("· \(m)").font(Theme.ui(13, .medium)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .background(Theme.flap).clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func cutPlanSection(_ p: ShaperProject) -> some View {
        VStack(alignment: .leading, spacing: showCutPlan ? 12 : 0) {
            Rail("Cut Plan Optimizer") {
                Button { showCutPlan.toggle() } label: {
                    Label(showCutPlan ? "Hide" : "Plan Cuts", systemImage: "scissors")
                        .font(Theme.board(10, .semibold, relativeTo: .caption2))
                        .foregroundStyle(Theme.onSteel)
                }
            }
            if showCutPlan {
                CutPlanOptimizerView(
                    api: api,
                    cutList: p.cutList,
                    projectId: model.isDemoMode ? nil : p.id
                )
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rail(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Data

    private func heroURL(_ p: ShaperProject) -> URL? {
        if let first = p.images.first, let url = imageURL(id: first.id) { return url }
        if let photo = p.photoUrl, let url = URL(string: photo) { return url }
        return nil
    }
    private func imageURL(id: Int) -> URL? {
        guard let key = model.userKey else { return nil }
        return api.imageURL(imageId: id, userKey: key)
    }
    private func dims(_ c: CutListItem) -> String {
        let parts = [c.length, c.width, c.thickness].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: " × ")
    }

    private func load() async {
        loading = p == nil; loadError = nil
        do { p = try await api.shaperProject(id: shaperId) }
        catch { loadError = error.localizedDescription }
        loading = false
    }

    private func deleteProject() async {
        guard !model.isDemoMode else { return }
        deleting = true
        do {
            try await api.deleteShaperProject(id: shaperId)
            Haptics.success()
            dismiss()
        } catch {
            deleting = false
        }
    }
}

import SwiftUI
import NintekKit

/// Project detail — read-only parity with `ProjectDetail.tsx`: hero banner +
/// overlapping meta card (status, title, description, plan links, stat grid),
/// wood/tools chips, sketches + inspiration galleries (with PDF tiles → PDFKit),
/// cut-list table, materials (read + purchased display), finish log, build-log
/// timeline, linked projects. Writes (edit/delete/toggle/add) land in Phase 3.
struct ProjectDetailView: View {
    let api: WorkshopAPI
    let projectId: Int
    @EnvironmentObject private var model: AppModel

    @State private var d: WSProjectDetail?
    @State private var loading = true
    @State private var loadError: String?
    @State private var gallery: GalleryPreview?
    @State private var pdfURL: IdentifiableURL?
    @State private var showEditForm = false

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
            }
        }
        .task { await load() }
        .fullScreenCover(item: $gallery) { ImageLightbox(preview: $0) }
        .sheet(item: $pdfURL) { PDFViewerSheet(url: $0.url) }
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
                                AuthImage(url: url, contentMode: .fill)
                                    .aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                AuthImage(url: url, contentMode: .fill)
                                    .aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func imageGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) { content() }
    }

    // MARK: Cut list

    @ViewBuilder private func cutListSection(_ d: WSProjectDetail) -> some View {
        if !d.cutList.isEmpty {
            SectionBox(title: "Cut List",
                       trailing: AnyView(Text("\(d.cutList.count) part\(d.cutList.count == 1 ? "" : "s")")
                        .font(.system(size: 13)).foregroundStyle(Theme.subtle))) {
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

    // MARK: Materials

    @ViewBuilder private func materialsSection(_ d: WSProjectDetail) -> some View {
        if !d.materials.isEmpty {
            SectionBox(title: "Materials & Hardware",
                       trailing: AnyView(Text("Total: \(money(d.totalCost))").font(.system(size: 13)).foregroundStyle(Theme.subtle))) {
                VStack(spacing: 0) {
                    ForEach(Array(d.materials.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Divider().overlay(Theme.line) }
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
                    }
                }
                .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    // MARK: Finish log

    @ViewBuilder private func finishLogSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Finish Log", icon: "drop.fill") {
            if d.finishLog.isEmpty {
                emptyNote("No finish entries yet.")
            } else {
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
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                }
                .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    // MARK: Build log

    @ViewBuilder private func buildLogSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Build Log", icon: "book.closed.fill") {
            if d.buildLog.isEmpty {
                emptyNote("No build notes yet. Document your progress here.")
            } else {
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

    // MARK: Linked projects

    @ViewBuilder private func linksSection(_ d: WSProjectDetail) -> some View {
        SectionBox(title: "Linked Projects", icon: "link") {
            if d.links.isEmpty {
                emptyNote("No linked projects.")
            } else {
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
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
            }
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
